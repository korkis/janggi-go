import {initializeApp} from "firebase-admin/app";
import {Timestamp, getFirestore} from "firebase-admin/firestore";
import functionsTest from "firebase-functions-test";
import {changeNickname} from "../src/callables/changeNickname";
import {claimAttendance} from "../src/callables/claimAttendance";
import {createProfile} from "../src/callables/createProfile";
import {INITIAL_APP_CONFIG} from "../src/models/appConfig";
import {CoinTransaction, CoinWallet} from "../src/models/coin";
import {Inventory, Purchase} from "../src/models/store";
import {setAppConfig} from "../src/repositories/configsRepository";
import * as firestoreRepository from "../src/repositories/firestore";
import {revenueCatWebhook} from "../src/webhooks/revenueCatWebhook";
import {TEST_PROJECT_ID} from "./testEnv";

// defineSecret("REVENUECAT_WEBHOOK_AUTH").value()가 읽는 값.
const WEBHOOK_AUTH = "test-webhook-auth";
process.env.REVENUECAT_WEBHOOK_AUTH = WEBHOOK_AUTH;

const fft = functionsTest({projectId: TEST_PROJECT_ID});
initializeApp({projectId: TEST_PROJECT_ID});
const db = getFirestore();

const wrappedCreateProfile = fft.wrap(createProfile);
const wrappedClaimAttendance = fft.wrap(claimAttendance);
const wrappedChangeNickname = fft.wrap(changeNickname);

function callAs(uid: string, data: unknown = {}) {
  return {data, auth: {uid, token: {uid}}, rawRequest: {headers: {}}, acceptsStreaming: false} as never;
}

/** RevenueCat이 보내는 웹훅을 흉내 내 부르고 응답 상태를 돌려준다. */
async function postWebhook(
  event: Record<string, unknown> | undefined,
  {authorization = WEBHOOK_AUTH, method = "POST"}: {authorization?: string; method?: string} = {},
): Promise<number> {
  let status = 0;
  const response = {
    status(code: number) {
      status = code;
      return this;
    },
    send() {
      return this;
    },
  };
  const request = {method, headers: {authorization}, body: {api_version: "1.0", event}};
  await (revenueCatWebhook as unknown as (req: unknown, res: unknown) => Promise<void>)(request, response);
  return status;
}

function purchaseEvent(productId: string, transactionId: string, overrides: Record<string, unknown> = {}) {
  return {
    type: "NON_RENEWING_PURCHASE",
    id: `event-${transactionId}`,
    app_user_id: "u1",
    original_app_user_id: "u1",
    aliases: ["u1"],
    product_id: productId,
    transaction_id: transactionId,
    store: "PLAY_STORE",
    environment: "PRODUCTION",
    ...overrides,
  };
}

function refundEvent(productId: string, transactionId: string, overrides: Record<string, unknown> = {}) {
  return purchaseEvent(productId, transactionId, {
    type: "CANCELLATION",
    id: `refund-${transactionId}`,
    cancel_reason: "CUSTOMER_SUPPORT",
    ...overrides,
  });
}

async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${TEST_PROJECT_ID}/databases/(default)/documents`, {
    method: "DELETE",
  });
}

async function getWallet(uid: string): Promise<CoinWallet> {
  return (await db.doc(`coin_wallets/${uid}`).get()).data() as CoinWallet;
}

async function setWallet(uid: string, freeCoins: number, paidCoins: number): Promise<void> {
  await db.doc(`coin_wallets/${uid}`).update({freeCoins, paidCoins, balance: freeCoins + paidCoins});
}

async function getInventory(uid: string): Promise<Inventory | undefined> {
  return (await db.doc(`inventories/${uid}`).get()).data() as Inventory | undefined;
}

async function getPurchase(purchaseId: string): Promise<Purchase | undefined> {
  return (await db.doc(`purchases/${purchaseId}`).get()).data() as Purchase | undefined;
}

async function getTransactions(uid: string): Promise<CoinTransaction[]> {
  const snapshot = await db.collection("coin_transactions").where("uid", "==", uid).get();
  return snapshot.docs.map((document) => document.data() as CoinTransaction);
}

/** 잔액이 내역의 합과 맞다. */
async function expectLedgerConsistent(uid: string): Promise<void> {
  const wallet = await getWallet(uid);
  const transactions = await getTransactions(uid);
  expect(wallet.balance).toBe(wallet.freeCoins + wallet.paidCoins);
  expect(transactions.reduce((sum, item) => sum + item.freeDelta, 0)).toBe(wallet.freeCoins);
  expect(transactions.reduce((sum, item) => sum + item.paidDelta, 0)).toBe(wallet.paidCoins);
}

beforeEach(async () => {
  await clearFirestore();
  await setAppConfig(INITIAL_APP_CONFIG);
  await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
});

afterAll(() => {
  fft.cleanup();
});

describe("인증과 요청 모양", () => {
  test("Authorization이 다르면 401이고 지급하지 않는다", async () => {
    const status = await postWebhook(purchaseEvent("coins_300", "T1"), {authorization: "wrong"});
    expect(status).toBe(401);
    expect((await getWallet("u1")).paidCoins).toBe(0);
  });

  test("POST가 아니면 405", async () => {
    expect(await postWebhook(purchaseEvent("coins_300", "T1"), {method: "GET"})).toBe(405);
  });

  test("event가 없거나 필수 필드가 없으면 400", async () => {
    expect(await postWebhook(undefined)).toBe(400);
    expect(await postWebhook({id: "x"})).toBe(400);
    expect(await postWebhook(purchaseEvent("coins_300", "T1", {transaction_id: undefined}))).toBe(400);
    expect((await getWallet("u1")).paidCoins).toBe(0);
  });

  test("처리하지 않는 일과 모르는 상품은 200으로 받고 아무것도 바꾸지 않는다", async () => {
    expect(await postWebhook({type: "TEST", id: "t"})).toBe(200);
    expect(await postWebhook({type: "TRANSFER", id: "t2", transferred_from: ["a"], transferred_to: ["b"]})).toBe(200);
    expect(await postWebhook(purchaseEvent("unknown_product", "T1"))).toBe(200);
    expect((await getWallet("u1")).paidCoins).toBe(0);
    expect(await getPurchase("PLAY_STORE_T1")).toBeUndefined();
  });

  test("로그인 전 익명 ID뿐이면 200으로 받고 지급하지 않는다", async () => {
    const event = purchaseEvent("coins_300", "T1", {
      app_user_id: "$RCAnonymousID:abc",
      original_app_user_id: "$RCAnonymousID:abc",
      aliases: ["$RCAnonymousID:abc"],
    });
    expect(await postWebhook(event)).toBe(200);
    expect(await getPurchase("PLAY_STORE_T1")).toBeUndefined();
  });

  test("app_user_id가 익명이어도 aliases에 uid가 있으면 그 사람에게 준다", async () => {
    const event = purchaseEvent("coins_300", "T1", {
      app_user_id: "$RCAnonymousID:abc",
      original_app_user_id: "$RCAnonymousID:abc",
      aliases: ["$RCAnonymousID:abc", "u1"],
    });
    expect(await postWebhook(event)).toBe(200);
    expect((await getWallet("u1")).paidCoins).toBe(300);
  });
});

describe("원문 기록", () => {
  async function getEvent(eventId: string) {
    return (await db.doc(`revenuecat_events/${eventId}`).get()).data();
  }

  test("처리 전에 원문을 저장하고 처리 결과를 적는다", async () => {
    const event = purchaseEvent("coins_300", "T1", {id: "e1", subscriber_attributes: {$email: {value: "a"}}});
    await postWebhook(event);

    const record = await getEvent("e1");
    expect(record).toMatchObject({
      type: "NON_RENEWING_PURCHASE",
      uid: "u1",
      productId: "coins_300",
      transactionId: "T1",
      store: "PLAY_STORE",
      environment: "PRODUCTION",
      deliveryCount: 1,
      result: "granted",
    });
    expect(JSON.parse(record?.payload as string)).toEqual({api_version: "1.0", event});
    expect(record?.processedAt).toBeInstanceOf(Timestamp);
    const years = (record?.expiresAt as Timestamp).toMillis() - (record?.receivedAt as Timestamp).toMillis();
    expect(Math.round(years / (365 * 24 * 60 * 60 * 1000))).toBe(5);
  });

  test("다시 받으면 받은 횟수를 늘리고 결과를 다시 적는다", async () => {
    const event = purchaseEvent("coins_300", "T1", {id: "e1"});
    await postWebhook(event);
    await postWebhook(event);
    expect(await getEvent("e1")).toMatchObject({deliveryCount: 2, result: "duplicate"});
  });

  test.each([
    {name: "처리하지 않는 일", event: {type: "TRANSFER", id: "e1"}, status: 200, result: "ignored"},
    {name: "모르는 상품", event: purchaseEvent("unknown", "T1", {id: "e1"}), status: 200, result: "unresolved"},
    {name: "먼저 온 환불", event: refundEvent("coins_300", "T1", {id: "e1"}), status: 200, result: "beforePurchase"},
    {name: "필드 없음", event: {id: "e1", type: "CANCELLATION"}, status: 400, result: "invalid"},
  ])("$name도 원문을 남긴다", async ({event, status, result}) => {
    expect(await postWebhook(event)).toBe(status);
    expect((await getEvent("e1"))?.result).toBe(result);
  });

  test("처리에 실패하면 500을 돌려주고 실패로 적으며, 다시 받으면 처리한다", async () => {
    const event = purchaseEvent("coins_300", "T1", {id: "e1"});
    const spy = jest.spyOn(firestoreRepository, "runTransaction").mockRejectedValueOnce(new Error("장애"));

    expect(await postWebhook(event)).toBe(500);
    expect((await getEvent("e1"))?.result).toBe("failed");
    expect((await getWallet("u1")).paidCoins).toBe(0);
    spy.mockRestore();

    expect(await postWebhook(event)).toBe(200);
    expect(await getEvent("e1")).toMatchObject({deliveryCount: 2, result: "granted"});
    expect((await getWallet("u1")).paidCoins).toBe(300);
  });

  test("인증에 실패하거나 id가 없으면 저장하지 않는다", async () => {
    await postWebhook(purchaseEvent("coins_300", "T1", {id: "e1"}), {authorization: "wrong"});
    expect(await postWebhook(purchaseEvent("coins_300", "T2", {id: undefined}))).toBe(400);
    expect((await db.collection("revenuecat_events").get()).empty).toBe(true);
    expect((await getWallet("u1")).paidCoins).toBe(0);
  });
});

describe("충전", () => {
  test.each([
    {productId: "coins_300", coins: 300},
    {productId: "coins_1100", coins: 1100},
    {productId: "coins_3000", coins: 3000},
  ])("$productId는 유상 $coins엽전을 주고 내역과 구매 기록을 남긴다", async ({productId, coins}) => {
    expect(await postWebhook(purchaseEvent(productId, "GPA.1234"))).toBe(200);

    expect(await getWallet("u1")).toMatchObject({freeCoins: 300, paidCoins: coins, balance: 300 + coins});
    expect((await db.doc("coin_transactions/coinPurchase_u1_PLAY_STORE_GPA.1234").get()).data()).toMatchObject({
      uid: "u1",
      reason: "coinPurchase",
      freeDelta: 0,
      paidDelta: coins,
      freeBalance: 300,
      paidBalance: coins,
    });
    expect(await getPurchase("PLAY_STORE_GPA.1234")).toMatchObject({
      uid: "u1",
      productId,
      store: "PLAY_STORE",
      transactionId: "GPA.1234",
      environment: "PRODUCTION",
      status: "granted",
      refundedAt: null,
    });
    await expectLedgerConsistent("u1");
  });

  test("같은 영수증은 다시 와도, 동시에 와도 한 번만 준다", async () => {
    const statuses = await Promise.all(Array.from({length: 4}, () => postWebhook(purchaseEvent("coins_300", "T1"))));
    expect(statuses).toEqual([200, 200, 200, 200]);
    expect(await postWebhook(purchaseEvent("coins_300", "T1"))).toBe(200);

    expect((await getWallet("u1")).paidCoins).toBe(300);
    await expectLedgerConsistent("u1");
  }, 60000); // 에뮬레이터는 같은 문서를 여러 트랜잭션이 잡으면 잠금이 풀리기를 기다려 오래 걸린다.

  test("같은 영수증이 다른 계정으로 와도 다시 주지 않는다", async () => {
    await wrappedCreateProfile(callAs("u2", {nickname: "장기신"}));
    await postWebhook(purchaseEvent("coins_300", "T1"));
    await postWebhook(purchaseEvent("coins_300", "T1", {app_user_id: "u2", original_app_user_id: "u2", aliases: []}));

    expect((await getWallet("u2")).paidCoins).toBe(0);
    expect((await getPurchase("PLAY_STORE_T1"))?.uid).toBe("u1");
  });

  test("스토어가 다르면 같은 번호여도 다른 영수증이다", async () => {
    await postWebhook(purchaseEvent("coins_300", "1000"));
    await postWebhook(purchaseEvent("coins_300", "1000", {store: "APP_STORE"}));
    expect((await getWallet("u1")).paidCoins).toBe(600);
  });

  test("문서 ID로 쓸 수 없는 글자가 있는 영수증 번호도 받는다", async () => {
    expect(await postWebhook(purchaseEvent("coins_300", "a/b"))).toBe(200);
    expect((await getWallet("u1")).paidCoins).toBe(300);
    expect(await getPurchase("PLAY_STORE_a%2Fb")).toBeDefined();
  });

  test("coinSaleEnabled가 꺼져 있어도 돈이 나간 충전은 준다", async () => {
    await setAppConfig({...INITIAL_APP_CONFIG, coinSaleEnabled: false});
    expect(await postWebhook(purchaseEvent("coins_300", "T1"))).toBe(200);
    expect((await getWallet("u1")).paidCoins).toBe(300);
  });

  test("탈퇴를 눌렀어도 지우기 전이면 준다", async () => {
    await db.doc("users/u1").update({deletedAt: Timestamp.now()});
    await postWebhook(purchaseEvent("coins_300", "T1"));
    expect((await getWallet("u1")).paidCoins).toBe(300);
  });

  test("지갑이 없으면(지운 계정) 지급하지 못한 것으로 기록하고 다시 보내게 하지 않는다", async () => {
    const event = purchaseEvent("coins_300", "T1", {app_user_id: "gone", original_app_user_id: "gone", aliases: []});
    expect(await postWebhook(event)).toBe(200);
    expect(await getPurchase("PLAY_STORE_T1")).toMatchObject({uid: "gone", status: "ungranted"});
    expect((await db.doc("coin_wallets/gone").get()).exists).toBe(false);
  });
});

describe("충전 환불", () => {
  test("쓰지 않았으면 유상에서 뺀다", async () => {
    await postWebhook(purchaseEvent("coins_1100", "T1"));
    expect(await postWebhook(refundEvent("coins_1100", "T1"))).toBe(200);

    expect(await getWallet("u1")).toMatchObject({freeCoins: 300, paidCoins: 0, balance: 300});
    expect((await db.doc("coin_transactions/coinPurchaseRefund_u1_PLAY_STORE_T1").get()).data()).toMatchObject({
      reason: "coinPurchaseRefund",
      freeDelta: 0,
      paidDelta: -1100,
    });
    const purchase = await getPurchase("PLAY_STORE_T1");
    expect(purchase?.status).toBe("refunded");
    expect(purchase?.refundedAt).toBeInstanceOf(Timestamp);
    await expectLedgerConsistent("u1");
  });

  test("유상이 모자라면 무상에서 뺀다", async () => {
    await postWebhook(purchaseEvent("coins_1100", "T1"));
    await setWallet("u1", 2000, 100);
    await db.doc("coin_transactions/coinPurchase_u1_PLAY_STORE_T1").update({paidDelta: 100});
    await db.doc("coin_transactions/signup_u1").update({freeDelta: 2000});

    await postWebhook(refundEvent("coins_1100", "T1"));

    expect(await getWallet("u1")).toMatchObject({freeCoins: 1000, paidCoins: 0, balance: 1000});
    await expectLedgerConsistent("u1");
  });

  test("그래도 모자라면 잔액이 음수가 되고, 메울 때까지 쓸 수 없다", async () => {
    await postWebhook(purchaseEvent("coins_1100", "T1"));
    await setWallet("u1", 0, 100);

    await postWebhook(refundEvent("coins_1100", "T1"));

    expect(await getWallet("u1")).toMatchObject({freeCoins: -1000, paidCoins: 0, balance: -1000});
    await wrappedClaimAttendance(callAs("u1"));
    expect(await getWallet("u1")).toMatchObject({freeCoins: -970, paidCoins: 0, balance: -970});
  });

  test("빚이 있는 채로 다시 충전하면 빚을 메운 만큼만 쓸 수 있고 쓰면 빚이 먼저 갚인다", async () => {
    await wrappedChangeNickname(callAs("u1", {nickname: "장기신"}));
    await db.doc("users_private/u1").update({nicknameChangedAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z"))});
    await setWallet("u1", -100, 0);

    await postWebhook(purchaseEvent("coins_1100", "T2"));
    expect(await getWallet("u1")).toMatchObject({freeCoins: -100, paidCoins: 1100, balance: 1000});

    await wrappedChangeNickname(
      callAs("u1", {nickname: "장기귀신", coinCost: INITIAL_APP_CONFIG.coinNicknameChangeCost}),
    );
    expect(await getWallet("u1")).toMatchObject({freeCoins: 0, paidCoins: 700, balance: 700});
  });

  test("같은 환불은 다시 와도, 동시에 와도 한 번만 뺀다", async () => {
    await postWebhook(purchaseEvent("coins_1100", "T1"));
    await Promise.all(Array.from({length: 3}, () => postWebhook(refundEvent("coins_1100", "T1"))));
    await postWebhook(refundEvent("coins_1100", "T1"));

    expect((await getWallet("u1")).paidCoins).toBe(0);
    await expectLedgerConsistent("u1");
  }, 60000);

  test("환불이 구매보다 먼저 오면 뒤에 온 구매를 지급하지 않는다", async () => {
    expect(await postWebhook(refundEvent("coins_300", "T1"))).toBe(200);
    expect(await postWebhook(purchaseEvent("coins_300", "T1"))).toBe(200);

    expect(await getWallet("u1")).toMatchObject({paidCoins: 0, balance: 300});
    expect((await getPurchase("PLAY_STORE_T1"))?.status).toBe("refunded");
    await expectLedgerConsistent("u1");
  });

  test("환불 뒤 같은 영수증의 구매가 다시 와도 지급하지 않는다", async () => {
    await postWebhook(purchaseEvent("coins_300", "T1"));
    await postWebhook(refundEvent("coins_300", "T1"));
    await postWebhook(purchaseEvent("coins_300", "T1"));
    expect((await getWallet("u1")).paidCoins).toBe(0);
  });

  test("지운 계정의 환불은 기록만 바꾼다", async () => {
    await postWebhook(purchaseEvent("coins_300", "T1"));
    await db.doc("coin_wallets/u1").delete();

    expect(await postWebhook(refundEvent("coins_300", "T1"))).toBe(200);

    expect((await db.doc("coin_wallets/u1").get()).exists).toBe(false);
    expect((await getPurchase("PLAY_STORE_T1"))?.status).toBe("refunded");
  });

  test("지급하지 못한 구매의 환불도 기록만 바꾼다", async () => {
    const owner = {app_user_id: "gone", original_app_user_id: "gone", aliases: []};
    await postWebhook(purchaseEvent("coins_300", "T1", owner));
    await postWebhook(refundEvent("coins_300", "T1", owner));
    expect((await getPurchase("PLAY_STORE_T1"))?.status).toBe("refunded");
  });
});

describe("기물과 광고 제거", () => {
  test("기물을 사면 보관함에 넣고 바로 고른다. 엽전은 움직이지 않는다", async () => {
    await postWebhook(purchaseEvent("pieces_wood", "T1"));

    expect(await getInventory("u1")).toMatchObject({
      materials: ["wood"],
      selectedMaterial: "wood",
      adsRemoved: false,
    });
    expect(await getWallet("u1")).toMatchObject({freeCoins: 300, paidCoins: 0});

    await postWebhook(purchaseEvent("pieces_aluminum", "T2"));
    expect(await getInventory("u1")).toMatchObject({materials: ["wood", "aluminum"], selectedMaterial: "aluminum"});
  });

  test("광고 제거를 사도 고른 기물은 그대로다", async () => {
    await postWebhook(purchaseEvent("remove_ads", "T1"));
    expect(await getInventory("u1")).toMatchObject({materials: [], selectedMaterial: "plastic", adsRemoved: true});
  });

  test("같은 영수증은 한 번만 넣는다", async () => {
    await postWebhook(purchaseEvent("pieces_wood", "T1"));
    await db.doc("inventories/u1").update({selectedMaterial: "plastic"});
    await postWebhook(purchaseEvent("pieces_wood", "T1"));
    expect(await getInventory("u1")).toMatchObject({materials: ["wood"], selectedMaterial: "plastic"});
  });

  test("쓰던 기물이 환불되면 기본 기물로 돌아간다", async () => {
    await postWebhook(purchaseEvent("pieces_wood", "T1"));
    await postWebhook(refundEvent("pieces_wood", "T1"));
    expect(await getInventory("u1")).toMatchObject({materials: [], selectedMaterial: "plastic"});
  });

  test("다른 기물을 쓰는 중이면 고른 기물은 그대로다", async () => {
    await postWebhook(purchaseEvent("pieces_wood", "T1"));
    await postWebhook(purchaseEvent("pieces_aluminum", "T2"));
    await postWebhook(refundEvent("pieces_wood", "T1"));
    expect(await getInventory("u1")).toMatchObject({materials: ["aluminum"], selectedMaterial: "aluminum"});
  });

  test("두 스토어에서 산 기물은 하나를 환불해도 남고 둘 다 환불하면 없어진다", async () => {
    await postWebhook(purchaseEvent("pieces_wood", "T1"));
    await postWebhook(purchaseEvent("pieces_wood", "2000", {store: "APP_STORE"}));

    await postWebhook(refundEvent("pieces_wood", "T1"));
    expect(await getInventory("u1")).toMatchObject({materials: ["wood"], selectedMaterial: "wood"});

    await postWebhook(refundEvent("pieces_wood", "2000", {store: "APP_STORE"}));
    expect(await getInventory("u1")).toMatchObject({materials: [], selectedMaterial: "plastic"});
  });

  test("광고 제거가 환불되면 되돌린다", async () => {
    await postWebhook(purchaseEvent("remove_ads", "T1"));
    await postWebhook(refundEvent("remove_ads", "T1"));
    expect((await getInventory("u1"))?.adsRemoved).toBe(false);
  });

  test("환불은 웹훅의 사용자가 아니라 영수증의 주인에게서 돌려받는다", async () => {
    await wrappedCreateProfile(callAs("u2", {nickname: "장기신"}));
    await postWebhook(purchaseEvent("pieces_wood", "T1"));
    await postWebhook(refundEvent("pieces_wood", "T1", {app_user_id: "u2", original_app_user_id: "u2", aliases: []}));
    expect((await getInventory("u1"))?.materials).toEqual([]);
    expect(await getInventory("u2")).toBeUndefined();
  });
});
