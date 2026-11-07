import {createSign, generateKeyPairSync} from "node:crypto";
import dayjs from "dayjs";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import functionsTest from "firebase-functions-test";
import {createProfile} from "../src/callables/createProfile";
import {
  ADMOB_REWARDED_AD_UNITS,
  ADMOB_VERIFIER_KEYS_CACHE_HOURS,
  ADMOB_VERIFIER_KEYS_REFRESH_SECONDS,
  ADMOB_VERIFIER_KEYS_URL,
} from "../src/config";
import {INITIAL_APP_CONFIG} from "../src/models/appConfig";
import {CoinTransaction, CoinWallet} from "../src/models/coin";
import {setAppConfig} from "../src/repositories/configsRepository";
import {getAdmobVerifierKey} from "../src/services/admobVerifierKeys";
import {getCoinDay} from "../src/services/coinService";
import {admobRewardCallback} from "../src/webhooks/admobRewardCallback";
import {TEST_PROJECT_ID, callConcurrently} from "./testEnv";

const fft = functionsTest({projectId: TEST_PROJECT_ID});
initializeApp({projectId: TEST_PROJECT_ID});
const db = getFirestore();
const wrappedCreateProfile = fft.wrap(createProfile);

const AD_UNIT = "2747237135";
const KEY_ID = "1234567890";
const REWARD = INITIAL_APP_CONFIG.coinRewardedAdReward;
const LIMIT = INITIAL_APP_CONFIG.coinRewardedAdDailyLimit;
const SIGNUP = INITIAL_APP_CONFIG.coinSignupBonus;
// 200이 아니면 구글이 다시 보내는 횟수(src/webhooks/admobRewardCallback.ts).
const CALLBACK_RESENDS = 5;

// 구글 대신 콜백에 서명하는 키. 구글과 같은 P-256이다.
const {privateKey, publicKey} = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
const publicPem = publicKey.export({type: "spki", format: "pem"}).toString();

// 진짜 공개 키 주소 대신 이 키를 돌려준다. 다른 주소(에뮬레이터)는 그대로 부른다.
const realFetch = global.fetch;
let keyFetches = 0;
const fetchSpy = jest.spyOn(global, "fetch").mockImplementation(async (input, init) => {
  if (input === ADMOB_VERIFIER_KEYS_URL) {
    keyFetches++;
    return new Response(JSON.stringify({keys: [{keyId: Number(KEY_ID), pem: publicPem, base64: "unused"}]}));
  }
  return realFetch(input, init);
});

function sign(content: string): string {
  return createSign("sha256").update(content).sign(privateKey).toString("base64url");
}

/** 구글이 보내는 모양의 쿼리 문자열. signature와 key_id가 맨 뒤다. */
function buildQuery(transactionId: string, overrides: Record<string, string> = {}, keyId = KEY_ID): string {
  const params = {
    ad_network: "5450213213286189855",
    ad_unit: AD_UNIT,
    reward_amount: "9999",
    reward_item: "coins",
    timestamp: String(dayjs().valueOf()),
    transaction_id: transactionId,
    user_id: "u1",
    ...overrides,
  };
  const content = Object.entries(params)
    .filter(([, value]) => value !== "")
    .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
    .join("&");
  return `${content}&signature=${sign(content)}&key_id=${keyId}`;
}

/** AdMob 콜백을 흉내 내 부르고 응답 상태를 돌려준다. */
async function callback(query: string, method = "GET"): Promise<number> {
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
  const request = {method, originalUrl: `/admobRewardCallback?${query}`, headers: {}};
  await (admobRewardCallback as unknown as (req: unknown, res: unknown) => Promise<void>)(request, response);
  return status;
}

/** 500이면 구글처럼 다시 보낸다. 동시 호출은 에뮬레이터의 닫힌 트랜잭션 오류로 500이 될 수 있다. */
async function callbackWithResends(query: string): Promise<number> {
  let status = await callback(query);
  for (let resend = 0; status === 500 && resend < CALLBACK_RESENDS; resend++) {
    status = await callback(query);
  }
  return status;
}

async function getWallet(uid: string): Promise<CoinWallet> {
  return (await db.doc(`coin_wallets/${uid}`).get()).data() as CoinWallet;
}

async function getRewardTransactions(uid: string): Promise<CoinTransaction[]> {
  const snapshot = await db.collection("coin_transactions").where("uid", "==", uid).get();
  return snapshot.docs.map((document) => document.data() as CoinTransaction).filter((item) => item.reason === "rewardedAd");
}

async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${TEST_PROJECT_ID}/databases/(default)/documents`, {
    method: "DELETE",
  });
}

function callAs(uid: string, data: unknown) {
  return {data, auth: {uid, token: {uid}}, rawRequest: {headers: {}}, acceptsStreaming: false} as never;
}

beforeAll(() => {
  ADMOB_REWARDED_AD_UNITS.push(AD_UNIT);
});

beforeEach(async () => {
  await clearFirestore();
  await setAppConfig(INITIAL_APP_CONFIG);
  await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
});

afterAll(() => {
  fetchSpy.mockRestore();
  fft.cleanup();
});

// 키를 아직 읽지 않은 상태가 필요하므로 맨 앞에 둔다.
describe("공개 키", () => {
  test("키를 읽지 못하면 500이라 구글이 다시 보내고, 읽게 되면 준다", async () => {
    fetchSpy.mockImplementationOnce(() => Promise.resolve(new Response("", {status: 503})));
    const query = buildQuery("tx1");
    expect(await callback(query)).toBe(500);
    expect(await getRewardTransactions("u1")).toHaveLength(0);

    expect(await callback(query)).toBe(200);
    expect(await getRewardTransactions("u1")).toHaveLength(1);
  });

  test("24시간 안에는 다시 읽지 않고, 모르는 키는 간격을 두고만 다시 읽는다", async () => {
    // 시계만 바꾼다. 이 안에서 Firestore를 부르지 않는다.
    jest.useFakeTimers({
      doNotFake: [
        "hrtime",
        "nextTick",
        "performance",
        "queueMicrotask",
        "setImmediate",
        "clearImmediate",
        "setInterval",
        "clearInterval",
        "setTimeout",
        "clearTimeout",
      ],
    });
    try {
      const start = dayjs().add(ADMOB_VERIFIER_KEYS_CACHE_HOURS, "hour");
      jest.setSystemTime(start.toDate());
      expect(await getAdmobVerifierKey(KEY_ID)).toBe(publicPem);
      const fetches = keyFetches;

      jest.setSystemTime(start.add(ADMOB_VERIFIER_KEYS_CACHE_HOURS - 1, "hour").toDate());
      expect(await getAdmobVerifierKey(KEY_ID)).toBe(publicPem);
      expect(keyFetches).toBe(fetches);

      jest.setSystemTime(start.add(ADMOB_VERIFIER_KEYS_CACHE_HOURS, "hour").toDate());
      expect(await getAdmobVerifierKey(KEY_ID)).toBe(publicPem);
      expect(keyFetches).toBe(fetches + 1);

      expect(await getAdmobVerifierKey("999")).toBeNull();
      expect(await getAdmobVerifierKey("999")).toBeNull();
      expect(keyFetches).toBe(fetches + 1);

      const later = start.add(ADMOB_VERIFIER_KEYS_CACHE_HOURS, "hour").add(ADMOB_VERIFIER_KEYS_REFRESH_SECONDS, "second");
      jest.setSystemTime(later.toDate());
      expect(await getAdmobVerifierKey("999")).toBeNull();
      expect(keyFetches).toBe(fetches + 2);
    } finally {
      jest.useRealTimers();
    }
  });
});

describe("지급", () => {
  test("서명이 맞으면 configs/app의 값을 무상으로 주고 내역을 남긴다", async () => {
    expect(await callback(buildQuery("tx1"))).toBe(200);

    const wallet = await getWallet("u1");
    expect(wallet).toMatchObject({
      freeCoins: SIGNUP + REWARD,
      paidCoins: 0,
      balance: SIGNUP + REWARD,
      rewardedAdDay: getCoinDay(dayjs()),
      rewardedAdCount: 1,
    });
    const transaction = (await db.doc("coin_transactions/rewardedAd_u1_tx1").get()).data();
    expect(transaction).toMatchObject({uid: "u1", reason: "rewardedAd", freeDelta: REWARD, paidDelta: 0, gameId: null});
  });

  test("값을 configs/app에서 바꾸면 바꾼 값을 준다. 콜백의 reward_amount는 쓰지 않는다", async () => {
    await setAppConfig({...INITIAL_APP_CONFIG, coinRewardedAdReward: 50});
    expect(await callback(buildQuery("tx1", {reward_amount: "1000"}))).toBe(200);
    expect((await getWallet("u1")).freeCoins).toBe(SIGNUP + 50);
  });

  test("custom_data가 있어도 서명을 그대로 확인한다", async () => {
    expect(await callback(buildQuery("tx1", {custom_data: "a b&signature=x"}))).toBe(200);
    expect((await getWallet("u1")).rewardedAdCount).toBe(1);
  });

  test("옛 지갑(횟수 필드 없음)에도 준다", async () => {
    await db.doc("coin_wallets/u1").update({rewardedAdDay: null, rewardedAdCount: null});
    expect(await callback(buildQuery("tx1"))).toBe(200);
    expect((await getWallet("u1")).rewardedAdCount).toBe(1);
  });
});

describe("중복 방지", () => {
  test("같은 콜백이 다시 오면 200으로 받고 한 번만 준다", async () => {
    const query = buildQuery("tx1");
    expect(await callback(query)).toBe(200);
    expect(await callback(query)).toBe(200);

    expect(await getRewardTransactions("u1")).toHaveLength(1);
    expect(await getWallet("u1")).toMatchObject({freeCoins: SIGNUP + REWARD, rewardedAdCount: 1});
  });

  test("동시에 와도 한 번만 준다", async () => {
    const query = buildQuery("tx1");
    const send = () => callbackWithResends(query);
    expect(await callConcurrently([send, send, send, send])).toEqual([200, 200, 200, 200]);

    expect(await getRewardTransactions("u1")).toHaveLength(1);
    expect(await getWallet("u1")).toMatchObject({freeCoins: SIGNUP + REWARD, rewardedAdCount: 1});
  });

  test("서명을 재사용해 user_id만 뒤에 덧붙여도 받는 사람이 바뀌지 않는다", async () => {
    await wrappedCreateProfile(callAs("u2", {nickname: "장기신"}));
    expect(await callback(`${buildQuery("tx1")}&user_id=u2`)).toBe(403);
    expect((await getWallet("u2")).freeCoins).toBe(SIGNUP);
    expect((await getWallet("u1")).freeCoins).toBe(SIGNUP);
  });
});

describe("하루 횟수", () => {
  test("하루 횟수까지만 주고 넘으면 200으로 받고 주지 않는다", async () => {
    for (let index = 0; index < LIMIT + 1; index++) {
      expect(await callback(buildQuery(`tx${index}`))).toBe(200);
    }

    expect(await getRewardTransactions("u1")).toHaveLength(LIMIT);
    expect(await getWallet("u1")).toMatchObject({freeCoins: SIGNUP + REWARD * LIMIT, rewardedAdCount: LIMIT});
  });

  test("다음 날이면 다시 센다", async () => {
    const yesterday = getCoinDay(dayjs().subtract(1, "day"));
    await db.doc("coin_wallets/u1").update({rewardedAdDay: yesterday, rewardedAdCount: LIMIT});

    expect(await callback(buildQuery("tx1"))).toBe(200);

    expect(await getWallet("u1")).toMatchObject({rewardedAdDay: getCoinDay(dayjs()), rewardedAdCount: 1});
  });

  test("횟수를 configs/app에서 줄이면 바로 적용한다", async () => {
    await setAppConfig({...INITIAL_APP_CONFIG, coinRewardedAdDailyLimit: 1});
    await callback(buildQuery("tx1"));
    await callback(buildQuery("tx2"));
    expect(await getRewardTransactions("u1")).toHaveLength(1);
  });

  test("동시에 와도 횟수를 넘지 않는다", async () => {
    await db.doc("coin_wallets/u1").update({rewardedAdDay: getCoinDay(dayjs()), rewardedAdCount: LIMIT - 1});
    const send = (index: number) => () => callbackWithResends(buildQuery(`tx${index}`));
    expect(await callConcurrently([send(1), send(2), send(3)])).toEqual([200, 200, 200]);

    expect(await getRewardTransactions("u1")).toHaveLength(1);
    expect((await getWallet("u1")).rewardedAdCount).toBe(LIMIT);
  });
});

describe("스위치", () => {
  test("rewardedAdEnabled를 끄면 서명이 맞아도 주지 않는다", async () => {
    await setAppConfig({...INITIAL_APP_CONFIG, rewardedAdEnabled: false});

    expect(await callback(buildQuery("tx1"))).toBe(200);

    expect((await getWallet("u1")).freeCoins).toBe(SIGNUP);
    expect(await getRewardTransactions("u1")).toHaveLength(0);
  });

  test("다시 켜면 다음 광고부터 준다", async () => {
    await setAppConfig({...INITIAL_APP_CONFIG, rewardedAdEnabled: false});
    await callback(buildQuery("tx1"));
    await setAppConfig(INITIAL_APP_CONFIG);
    await callback(buildQuery("tx2"));
    expect(await getRewardTransactions("u1")).toHaveLength(1);
  });

  test("bannerAdEnabled를 꺼도 보상형은 그대로 준다", async () => {
    await setAppConfig({...INITIAL_APP_CONFIG, bannerAdEnabled: false});
    await callback(buildQuery("tx1"));
    expect(await getRewardTransactions("u1")).toHaveLength(1);
  });

  test("광고 제거를 샀어도 보상형은 그대로 준다", async () => {
    await db.doc("inventories/u1").set({materials: [], selectedMaterial: "plastic", adsRemoved: true});
    await callback(buildQuery("tx1"));
    expect(await getRewardTransactions("u1")).toHaveLength(1);
  });
});

describe("요청 검사", () => {
  test("서명이 틀리면 403이고 주지 않는다", async () => {
    const query = buildQuery("tx1");
    const forged = query.replace("user_id=u1", "user_id=u2");
    expect(await callback(forged)).toBe(403);
    expect((await getWallet("u1")).freeCoins).toBe(SIGNUP);
  });

  test.each([
    "",
    "transaction_id=tx1&user_id=u1",
    "transaction_id=tx1&user_id=u1&signature=abc",
    "transaction_id=tx1&user_id=u1&key_id=1234567890",
    `transaction_id=tx1&user_id=u1&signature=not-a-signature&key_id=${KEY_ID}`,
    `signature=abc&key_id=${KEY_ID}`,
  ])("서명 필드가 없거나 틀린 모양이면 403이다: %s", async (query) => {
    expect(await callback(query)).toBe(403);
    expect(await getRewardTransactions("u1")).toHaveLength(0);
  });

  test("모르는 key_id면 403이다", async () => {
    expect(await callback(buildQuery("tx1", {}, "999"))).toBe(403);
    expect(await getRewardTransactions("u1")).toHaveLength(0);
  });

  test("다른 키로 서명한 콜백은 403이다", async () => {
    const other = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
    const content = `ad_unit=${AD_UNIT}&transaction_id=tx1&user_id=u1`;
    const signature = createSign("sha256").update(content).sign(other.privateKey).toString("base64url");
    expect(await callback(`${content}&signature=${signature}&key_id=${KEY_ID}`)).toBe(403);
  });

  test("서명이 맞아도 우리 광고 단위가 아니면 200으로 받고 주지 않는다", async () => {
    expect(await callback(buildQuery("tx1", {ad_unit: "1234567890"}))).toBe(200);
    expect(await getRewardTransactions("u1")).toHaveLength(0);
  });

  test("user_id나 transaction_id가 없으면 200으로 받고 주지 않는다", async () => {
    expect(await callback(buildQuery("tx1", {user_id: ""}))).toBe(200);
    expect(await callback(buildQuery(""))).toBe(200);
    expect(await getRewardTransactions("u1")).toHaveLength(0);
  });

  test("지갑이 없는 사용자면 200으로 받고 지갑을 만들지 않는다", async () => {
    expect(await callback(buildQuery("tx1", {user_id: "nobody"}))).toBe(200);
    expect((await db.doc("coin_wallets/nobody").get()).exists).toBe(false);
  });

  test("GET이 아니면 405다", async () => {
    expect(await callback(buildQuery("tx1"), "POST")).toBe(405);
  });
});
