import {Timestamp, Transaction} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {REVENUECAT_ANONYMOUS_ID_PREFIX, STORE_PRODUCTS} from "../config";
import {CoinWallet} from "../models/coin";
import {Inventory, PieceMaterial, Purchase, PurchaseStatus, RevenueCatEvent, StoreProduct} from "../models/store";
import {getWalletInTransaction} from "../repositories/coinWalletsRepository";
import {getAppConfig} from "../repositories/configsRepository";
import {runTransaction} from "../repositories/firestore";
import {getInventoryInTransaction, setInventoryInTransaction} from "../repositories/inventoriesRepository";
import {
  createPurchaseInTransaction,
  getPurchaseId,
  getPurchaseInTransaction,
  hasOtherGrantedPurchaseInTransaction,
  markPurchaseRefundedInTransaction,
} from "../repositories/purchasesRepository";
import {grantPurchasedCoinsInTransaction, takeBackPurchasedCoinsInTransaction} from "./coinService";

// RevenueCat 웹훅의 일 종류 중 처리하는 것. 한 번 사는 상품의 구매와, 그 환불이다.
const EVENT_NON_RENEWING_PURCHASE = "NON_RENEWING_PURCHASE";
const EVENT_CANCELLATION = "CANCELLATION";

/** 필드가 빠진 웹훅. 다시 보내도 같으므로 앱 오류가 아니라 요청 오류로 돌려준다. */
export class InvalidRevenueCatEventError extends Error {}

/** 처리할 구매나 환불의 필드. */
interface PurchaseEvent {
  uid: string;
  productId: string;
  product: StoreProduct;
  store: string;
  transactionId: string;
  environment: string | null;
}

function requireString(value: unknown, name: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new InvalidRevenueCatEventError(`RevenueCat 웹훅에 ${name}이 없습니다`);
  }
  return value;
}

/**
 * 구매한 사람의 Firebase uid. 앱은 로그인한 뒤에만 팔고 RevenueCat에 uid로 로그인하므로 `app_user_id`가 uid다.
 * 익명 ID가 오면 함께 온 다른 ID에서 찾는다. 없으면 null이다.
 */
function findUid(event: RevenueCatEvent): string | null {
  const aliases = Array.isArray(event.aliases) ? (event.aliases as unknown[]) : [];
  for (const candidate of [event.app_user_id, event.original_app_user_id, ...aliases]) {
    if (
      typeof candidate === "string" &&
      candidate.length > 0 &&
      !candidate.startsWith(REVENUECAT_ANONYMOUS_ID_PREFIX)
    ) {
      return candidate;
    }
  }
  return null;
}

/** 지갑이나 보관함을 바꾸지 않고 구매 기록만 만든다. */
function createPurchaseRecord(
  transaction: Transaction,
  purchaseId: string,
  event: PurchaseEvent,
  status: PurchaseStatus,
  now: Timestamp,
): void {
  const purchase: Purchase = {
    uid: event.uid,
    productId: event.productId,
    store: event.store,
    transactionId: event.transactionId,
    environment: event.environment,
    status,
    createdAt: now,
    refundedAt: status === PurchaseStatus.refunded ? now : null,
  };
  createPurchaseInTransaction(transaction, purchaseId, purchase);
}

/** 영구 상품을 보관함에 넣은 모양. 산 기물은 바로 고른다. */
function addToInventory(inventory: Inventory | null, product: StoreProduct, now: Timestamp): Inventory {
  const current: Inventory = inventory ?? {
    materials: [],
    selectedMaterial: PieceMaterial.plastic,
    adsRemoved: false,
    updatedAt: now,
  };
  if (product.kind === "material") {
    return {
      ...current,
      materials: [...new Set([...current.materials, product.material])],
      selectedMaterial: product.material,
      updatedAt: now,
    };
  }
  return {...current, adsRemoved: true, updatedAt: now};
}

/** 영구 상품을 보관함에서 뺀 모양. 쓰던 기물이면 기본 기물로 돌린다. */
function removeFromInventory(inventory: Inventory, product: StoreProduct, now: Timestamp): Inventory {
  if (product.kind === "material") {
    return {
      ...inventory,
      materials: inventory.materials.filter((material) => material !== product.material),
      selectedMaterial:
        inventory.selectedMaterial === product.material ? PieceMaterial.plastic : inventory.selectedMaterial,
      updatedAt: now,
    };
  }
  return {...inventory, adsRemoved: false, updatedAt: now};
}

/** 산 것을 지급한다. 같은 영수증이 이미 있으면(다시 온 웹훅, 먼저 온 환불) 아무것도 하지 않는다. 돌려준 값은 처리 결과다. */
async function grantPurchase(event: PurchaseEvent): Promise<PurchaseStatus | "duplicate"> {
  const purchaseId = getPurchaseId(event.store, event.transactionId);
  const {product, uid} = event;
  return runTransaction(async (transaction) => {
    const existing = await getPurchaseInTransaction(transaction, purchaseId);
    if (existing !== null) {
      return "duplicate";
    }
    const now = Timestamp.now();
    const wallet = await getWalletInTransaction(transaction, uid);
    if (wallet === null) {
      createPurchaseRecord(transaction, purchaseId, event, PurchaseStatus.ungranted, now);
      return PurchaseStatus.ungranted;
    }
    if (product.kind === "coins") {
      grantPurchasedCoinsInTransaction(transaction, uid, wallet, product.coins, purchaseId, now);
    } else {
      const inventory = await getInventoryInTransaction(transaction, uid);
      setInventoryInTransaction(transaction, uid, addToInventory(inventory, product, now));
    }
    createPurchaseRecord(transaction, purchaseId, event, PurchaseStatus.granted, now);
    return PurchaseStatus.granted;
  });
}

/** 지급했던 것을 돌려받는다. 호출하기 전에 지갑을 읽어 둔다. 다른 스토어에서 또 산 영구 상품은 그대로 둔다. */
async function takeBackInTransaction(
  transaction: Transaction,
  uid: string,
  productId: string,
  product: StoreProduct,
  wallet: CoinWallet,
  purchaseId: string,
  now: Timestamp,
): Promise<void> {
  if (product.kind === "coins") {
    takeBackPurchasedCoinsInTransaction(transaction, uid, wallet, product.coins, purchaseId, now);
    return;
  }
  const inventory = await getInventoryInTransaction(transaction, uid);
  const stillOwned = await hasOtherGrantedPurchaseInTransaction(transaction, uid, productId, purchaseId);
  if (inventory !== null && !stillOwned) {
    setInventoryInTransaction(transaction, uid, removeFromInventory(inventory, product, now));
  }
}

/**
 * 환불을 처리한다. 지급했던 것을 영수증의 주인에게서 돌려받는다. 이미 환불했으면 아무것도 하지 않는다.
 * 구매 기록이 없으면(환불이 먼저 왔다) 환불된 것으로 기록해 뒤에 오는 구매가 지급되지 않게 한다. 지운 계정이면 기록만 바꾼다.
 */
async function refundPurchase(event: PurchaseEvent): Promise<PurchaseStatus | "duplicate" | "beforePurchase"> {
  const purchaseId = getPurchaseId(event.store, event.transactionId);
  return runTransaction(async (transaction) => {
    const existing = await getPurchaseInTransaction(transaction, purchaseId);
    const now = Timestamp.now();
    if (existing === null) {
      createPurchaseRecord(transaction, purchaseId, event, PurchaseStatus.refunded, now);
      return "beforePurchase";
    }
    if (existing.status === PurchaseStatus.refunded) {
      return "duplicate";
    }
    if (existing.status === PurchaseStatus.granted) {
      const wallet = await getWalletInTransaction(transaction, existing.uid);
      if (wallet !== null) {
        await takeBackInTransaction(
          transaction,
          existing.uid,
          existing.productId,
          event.product,
          wallet,
          purchaseId,
          now,
        );
      }
    }
    markPurchaseRefundedInTransaction(transaction, purchaseId, now);
    return PurchaseStatus.refunded;
  });
}

/** 구매와 환불 일의 필드를 읽는다. 모르는 상품이나 찾을 수 없는 사용자면 null이다. 다시 보내도 같으므로 받은 것으로 치고 로그를 남긴다. */
function readPurchaseEvent(event: RevenueCatEvent): PurchaseEvent | null {
  const productId = requireString(event.product_id, "product_id");
  const transactionId = requireString(event.transaction_id, "transaction_id");
  const store = requireString(event.store, "store");
  const product = STORE_PRODUCTS[productId];
  if (product === undefined) {
    logger.error("revenueCatWebhook 모르는 상품", {productId, transactionId});
    return null;
  }
  const uid = findUid(event);
  if (uid === null) {
    logger.error("revenueCatWebhook 사용자를 찾지 못함", {productId, transactionId});
    return null;
  }
  const environment = typeof event.environment === "string" ? event.environment : null;
  return {uid, productId, product, store, transactionId, environment};
}

/**
 * RevenueCat 웹훅의 일 하나를 처리한다(docs/server.md의 앱 결제). 같은 일이 여러 번 오거나 순서가 바뀌어도 결과가 같다.
 * 돈은 스토어에서 이미 나갔으므로 `coinSaleEnabled`가 꺼져 있어도 지급한다. 꺼진 뒤의 충전은 로그로 찾는다.
 */
export async function handleRevenueCatEvent(event: RevenueCatEvent): Promise<void> {
  const type = requireString(event.type, "type");
  if (type !== EVENT_NON_RENEWING_PURCHASE && type !== EVENT_CANCELLATION) {
    logger.info("revenueCatWebhook 처리하지 않는 일", {type, id: event.id});
    return;
  }
  const purchaseEvent = readPurchaseEvent(event);
  if (purchaseEvent === null) {
    return;
  }
  const {uid, productId, transactionId, product} = purchaseEvent;
  if (type === EVENT_NON_RENEWING_PURCHASE) {
    if (product.kind === "coins" && !(await getAppConfig()).coinSaleEnabled) {
      logger.warn("revenueCatWebhook coinSaleEnabled가 꺼져 있는데 충전이 왔다", {uid, productId, transactionId});
    }
    const result = await grantPurchase(purchaseEvent);
    if (result === PurchaseStatus.ungranted) {
      logger.error("revenueCatWebhook 지갑이 없어 지급하지 못함", {uid, productId, transactionId});
    }
    logger.info("revenueCatWebhook 구매 완료", {uid, productId, transactionId, result});
    return;
  }
  const result = await refundPurchase(purchaseEvent);
  if (result === "beforePurchase") {
    logger.warn("revenueCatWebhook 구매 기록 없는 환불", {uid, productId, transactionId});
  }
  logger.info("revenueCatWebhook 환불 완료", {uid, productId, transactionId, result});
}
