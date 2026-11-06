import {Timestamp} from "firebase-admin/firestore";

/** 기물 재질. 앱의 `PieceMaterial`, 대국 서버의 `PieceMaterial`과 값을 일치시킨다(docs/database.md의 공통 enum). */
export const PieceMaterial = {
  plastic: "plastic",
  wood: "wood",
  aluminum: "aluminum",
} as const;
export type PieceMaterial = (typeof PieceMaterial)[keyof typeof PieceMaterial];

/**
 * Firestore `inventories/{uid}`. 산 상품과 고른 기물이다(docs/database.md). 첫 구매 때 만든다. 없으면 산 것이 없고 기본 기물을 쓴다.
 * 필드는 앱의 `Inventory`(app/lib/models/inventory.dart), 대국 서버의 `Inventory`(server/game/lib/models/inventory.dart)와 일치시킨다.
 */
export interface Inventory {
  // 산 재질. 기본 기물(plastic)은 넣지 않는다.
  materials: PieceMaterial[];
  // 고른 재질. plastic이거나 materials 안의 값이다. 앱이 보안 규칙을 거쳐 직접 바꾼다.
  selectedMaterial: PieceMaterial;
  adsRemoved: boolean;
  updatedAt: Timestamp;
}

/** 파는 상품이 주는 것(docs/monetization.md의 상품, 현금 충전). */
export type StoreProduct =
  {kind: "coins"; coins: number} | {kind: "material"; material: PieceMaterial} | {kind: "adsRemoved"};

/** 구매의 상태. `purchases.status`에 저장한다. */
export const PurchaseStatus = {
  // 지급했다.
  granted: "granted",
  // 환불됐다. 지급했던 것은 돌려받았다.
  refunded: "refunded",
  // 지갑이 없어(지운 계정) 지급하지 못했다.
  ungranted: "ungranted",
} as const;
export type PurchaseStatus = (typeof PurchaseStatus)[keyof typeof PurchaseStatus];

/**
 * Firestore `purchases/{purchaseId}`. 스토어 구매 기록이다(서버 전용). ID는 스토어와 영수증 번호로 정해 같은 영수증이 두 번 지급되지 않게 한다.
 */
export interface Purchase {
  uid: string;
  productId: string;
  // RevenueCat의 store 값(PLAY_STORE, APP_STORE).
  store: string;
  // 스토어의 영수증 번호.
  transactionId: string;
  // RevenueCat의 environment 값(PRODUCTION, SANDBOX). 심사와 비공개 테스트의 결제는 SANDBOX다.
  environment: string | null;
  status: PurchaseStatus;
  createdAt: Timestamp;
  refundedAt: Timestamp | null;
  // 탈퇴한 사용자를 지울 때 정한다. TTL 정책으로 지운다.
  expiresAt?: Timestamp;
}

/** RevenueCat 웹훅의 `event` 중 쓰는 필드(docs/server.md의 앱 결제). 일이 다르면 없는 필드가 있다. */
export interface RevenueCatEvent {
  id?: unknown;
  type?: unknown;
  app_user_id?: unknown;
  original_app_user_id?: unknown;
  aliases?: unknown;
  product_id?: unknown;
  transaction_id?: unknown;
  store?: unknown;
  environment?: unknown;
}
