import dayjs from "dayjs";
import {initializeApp} from "firebase-admin/app";
import {Timestamp, getFirestore} from "firebase-admin/firestore";
import functionsTest from "firebase-functions-test";
import {HttpsError} from "firebase-functions/https";
import {adminGetCoinStats} from "../src/callables/adminGetCoinStats";
import {changeNickname} from "../src/callables/changeNickname";
import {claimAttendance} from "../src/callables/claimAttendance";
import {claimCoinRescue} from "../src/callables/claimCoinRescue";
import {createProfile} from "../src/callables/createProfile";
import {INITIAL_APP_CONFIG} from "../src/models/appConfig";
import {CoinReason, CoinTransaction, CoinWallet} from "../src/models/coin";
import {setAppConfig} from "../src/repositories/configsRepository";
import {getCoinDay} from "../src/services/coinService";
import {TEST_PROJECT_ID} from "./testEnv";

const fft = functionsTest({projectId: TEST_PROJECT_ID});
initializeApp({projectId: TEST_PROJECT_ID});
const db = getFirestore();

const wrappedCreateProfile = fft.wrap(createProfile);
const wrappedChangeNickname = fft.wrap(changeNickname);
const wrappedClaimAttendance = fft.wrap(claimAttendance);
const wrappedClaimCoinRescue = fft.wrap(claimCoinRescue);
const wrappedGetCoinStats = fft.wrap(adminGetCoinStats);

const COST = INITIAL_APP_CONFIG.coinNicknameChangeCost;

function callAs(uid: string | null, data: unknown = {}, admin = false) {
  return {
    data,
    auth: uid === null ? undefined : {uid, token: {uid, admin}},
    rawRequest: {},
    acceptsStreaming: false,
  } as never;
}

async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${TEST_PROJECT_ID}/databases/(default)/documents`, {
    method: "DELETE",
  });
}

async function expectHttpsError(call: () => unknown): Promise<HttpsError> {
  try {
    await call();
  } catch (error) {
    expect(error).toBeInstanceOf(HttpsError);
    return error as HttpsError;
  }
  throw new Error("HttpsError로 실패해야 한다");
}

async function getWallet(uid: string): Promise<CoinWallet> {
  return (await db.doc(`coin_wallets/${uid}`).get()).data() as CoinWallet;
}

async function setWallet(uid: string, wallet: Partial<CoinWallet>): Promise<void> {
  const freeCoins = wallet.freeCoins ?? 0;
  const paidCoins = wallet.paidCoins ?? 0;
  await db.doc(`coin_wallets/${uid}`).set({
    attendanceDay: null,
    attendanceStreak: 0,
    rescueDay: null,
    updatedAt: Timestamp.now(),
    ...wallet,
    freeCoins,
    paidCoins,
    balance: freeCoins + paidCoins,
  });
}

async function getTransactions(uid: string): Promise<CoinTransaction[]> {
  const snapshot = await db.collection("coin_transactions").where("uid", "==", uid).get();
  return snapshot.docs.map((document) => document.data() as CoinTransaction);
}

/** 잔액이 내역의 합과 맞고 balance가 무상과 유상의 합인지 본다. */
async function expectLedgerConsistent(uid: string): Promise<void> {
  const wallet = await getWallet(uid);
  const transactions = await getTransactions(uid);
  expect(wallet.balance).toBe(wallet.freeCoins + wallet.paidCoins);
  expect(transactions.reduce((sum, item) => sum + item.freeDelta, 0)).toBe(wallet.freeCoins);
  expect(transactions.reduce((sum, item) => sum + item.paidDelta, 0)).toBe(wallet.paidCoins);
}

function daysAgo(days: number): string {
  return getCoinDay(dayjs().subtract(days, "day"));
}

beforeEach(async () => {
  await clearFirestore();
  await setAppConfig(INITIAL_APP_CONFIG);
});

afterAll(() => {
  fft.cleanup();
});

describe("가입", () => {
  test("프로필을 만들면 가입 엽전을 무상으로 주고 내역을 남긴다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));

    const wallet = await getWallet("u1");
    expect(wallet).toMatchObject({
      freeCoins: 300,
      paidCoins: 0,
      balance: 300,
      attendanceDay: null,
      attendanceStreak: 0,
      rescueDay: null,
    });
    const transaction = (await db.doc("coin_transactions/signup_u1").get()).data();
    expect(transaction).toMatchObject({
      uid: "u1",
      reason: CoinReason.signup,
      freeDelta: 300,
      paidDelta: 0,
      freeBalance: 300,
      paidBalance: 0,
      gameId: null,
    });
  });

  test("다시 불러도 동시에 불러도 한 번만 준다", async () => {
    await Promise.all(Array.from({length: 4}, (): unknown => wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}))));
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));

    expect((await getWallet("u1")).balance).toBe(300);
    expect(await getTransactions("u1")).toHaveLength(1);
  });

  test("가입 값은 configs/app을 따른다", async () => {
    await setAppConfig({...INITIAL_APP_CONFIG, coinSignupBonus: 7});
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    expect((await getWallet("u1")).balance).toBe(7);
  });
});

describe("출석", () => {
  beforeEach(async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
  });

  test("하루 한 번 준다", async () => {
    const first = await wrappedClaimAttendance(callAs("u1"));
    expect(first).toEqual({granted: true, amount: 30, streak: 1, balance: 330});
    const second = await wrappedClaimAttendance(callAs("u1"));
    expect(second).toEqual({granted: false, amount: 0, streak: 1, balance: 330});
    await expectLedgerConsistent("u1");
  });

  test("동시에 불러도 한 번만 준다", async () => {
    const results = await Promise.all(Array.from({length: 5}, () => wrappedClaimAttendance(callAs("u1"))));

    expect(results.filter((result) => result.granted)).toHaveLength(1);
    expect((await getWallet("u1")).balance).toBe(330);
    await expectLedgerConsistent("u1");
  });

  test.each([
    {lastDaysAgo: 1, streak: 1, expectedStreak: 2, expectedAmount: 30},
    {lastDaysAgo: 1, streak: 5, expectedStreak: 6, expectedAmount: 30},
    {lastDaysAgo: 1, streak: 6, expectedStreak: 7, expectedAmount: 100},
    {lastDaysAgo: 1, streak: 7, expectedStreak: 1, expectedAmount: 30},
    {lastDaysAgo: 2, streak: 6, expectedStreak: 1, expectedAmount: 30},
  ])("$lastDaysAgo일 전 $streak째 날이면 $expectedStreak째 날로 $expectedAmount", async (item) => {
    await setWallet("u2", {attendanceDay: daysAgo(item.lastDaysAgo), attendanceStreak: item.streak, freeCoins: 5});
    await db.doc("users/u2").set({nickname: "둘"});

    const result = await wrappedClaimAttendance(callAs("u2"));

    expect(result).toEqual({
      granted: true,
      amount: item.expectedAmount,
      streak: item.expectedStreak,
      balance: 5 + item.expectedAmount,
    });
    expect(await getWallet("u2")).toMatchObject({attendanceDay: daysAgo(0), attendanceStreak: item.expectedStreak});
  });

  test("지갑이 없는 사용자(엽전이 생기기 전 가입)도 받는다", async () => {
    await db.doc("users/old").set({nickname: "옛사람"});
    const result = await wrappedClaimAttendance(callAs("old"));
    expect(result).toEqual({granted: true, amount: 30, streak: 1, balance: 30});
  });

  test("프로필이 없거나 로그인하지 않으면 거절한다", async () => {
    const noProfile = await expectHttpsError(() => wrappedClaimAttendance(callAs("nobody")));
    expect(noProfile.details).toEqual({code: "profileRequired"});
    const noLogin = await expectHttpsError(() => wrappedClaimAttendance(callAs(null)));
    expect(noLogin.code).toBe("unauthenticated");
    expect((await db.doc("coin_wallets/nobody").get()).exists).toBe(false);
  });
});

describe("바닥 구제", () => {
  beforeEach(async () => {
    await db.doc("users/u1").set({nickname: "장기왕"});
  });

  test("기준 이상이면 주지 않는다", async () => {
    await setWallet("u1", {freeCoins: 5, paidCoins: 5});
    const result = await wrappedClaimCoinRescue(callAs("u1"));
    expect(result).toEqual({granted: false, amount: 0, balance: 10});
    expect((await getWallet("u1")).rescueDay).toBeNull();
  });

  test("기준 미만이면 하루 한 번 준다", async () => {
    await setWallet("u1", {freeCoins: 3, paidCoins: 6});
    const first = await wrappedClaimCoinRescue(callAs("u1"));
    expect(first).toEqual({granted: true, amount: 50, balance: 59});
    expect(await getWallet("u1")).toMatchObject({freeCoins: 53, paidCoins: 6, rescueDay: daysAgo(0)});

    // 다 써서 다시 기준 아래로 내려가도 그날은 더 받지 못한다.
    await setWallet("u1", {freeCoins: 0, rescueDay: daysAgo(0)});
    const second = await wrappedClaimCoinRescue(callAs("u1"));
    expect(second).toEqual({granted: false, amount: 0, balance: 0});
  });

  test("어제 받았으면 오늘 또 받는다", async () => {
    await setWallet("u1", {freeCoins: 0, rescueDay: daysAgo(1)});
    const result = await wrappedClaimCoinRescue(callAs("u1"));
    expect(result.granted).toBe(true);
  });

  test("동시에 불러도 한 번만 준다", async () => {
    await setWallet("u1", {freeCoins: 0});
    const results = await Promise.all(Array.from({length: 5}, () => wrappedClaimCoinRescue(callAs("u1"))));

    expect(results.filter((result) => result.granted)).toHaveLength(1);
    expect((await getWallet("u1")).balance).toBe(50);
  });

  test("기준과 값은 configs/app을 따른다", async () => {
    await setAppConfig({...INITIAL_APP_CONFIG, coinRescueThreshold: 100, coinRescueReward: 11});
    await setWallet("u1", {freeCoins: 99});
    const result = await wrappedClaimCoinRescue(callAs("u1"));
    expect(result).toEqual({granted: true, amount: 11, balance: 110});
  });
});

describe("닉네임 유료 변경", () => {
  /** 무료 변경을 쓰고 7일이 지난 사용자. */
  async function prepareUser(wallet: Partial<CoinWallet>): Promise<void> {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    await wrappedChangeNickname(callAs("u1", {nickname: "장기신"}));
    await db.doc("users_private/u1").update({nicknameChangedAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z"))});
    await setWallet("u1", wallet);
  }

  test("첫 변경은 엽전을 받지 않는다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    await wrappedChangeNickname(callAs("u1", {nickname: "장기신", coinCost: COST}));
    expect((await getWallet("u1")).balance).toBe(300);
    expect(await getTransactions("u1")).toHaveLength(1);
  });

  test("무상부터 쓰고 모자라면 유상을 쓴다", async () => {
    await prepareUser({freeCoins: 100, paidCoins: 250});

    await wrappedChangeNickname(callAs("u1", {nickname: "장기귀신", coinCost: COST}));

    expect(await getWallet("u1")).toMatchObject({freeCoins: 0, paidCoins: 50, balance: 50});
    const transaction = (await db.doc("coin_transactions/nicknameChange_u1_2").get()).data();
    expect(transaction).toMatchObject({
      reason: CoinReason.nicknameChange,
      freeDelta: -100,
      paidDelta: -200,
      freeBalance: 0,
      paidBalance: 50,
    });
    expect((await db.doc("users/u1").get()).data()?.nickname).toBe("장기귀신");
    expect((await db.doc("users_private/u1").get()).data()?.nicknameChangeCount).toBe(2);
  });

  test("무상이 넉넉하면 유상을 건드리지 않는다", async () => {
    await prepareUser({freeCoins: 400, paidCoins: 10});
    await wrappedChangeNickname(callAs("u1", {nickname: "장기귀신", coinCost: COST}));
    expect(await getWallet("u1")).toMatchObject({freeCoins: 100, paidCoins: 10});
  });

  test("coinCost가 없으면 옛 앱처럼 nicknameChangeNotFree로 거절하고 엽전을 받지 않는다", async () => {
    await prepareUser({freeCoins: 1000});
    const error = await expectHttpsError(() => wrappedChangeNickname(callAs("u1", {nickname: "장기귀신"})));
    expect(error.details).toEqual({code: "nicknameChangeNotFree"});
    expect((await getWallet("u1")).balance).toBe(1000);
  });

  test("값이 바뀌었으면 coinPriceChanged로 거절한다", async () => {
    await prepareUser({freeCoins: 1000});
    const error = await expectHttpsError(() =>
      wrappedChangeNickname(callAs("u1", {nickname: "장기귀신", coinCost: COST - 1})),
    );
    expect(error.details).toEqual({code: "coinPriceChanged"});
    expect((await getWallet("u1")).balance).toBe(1000);
  });

  test("엽전이 모자라면 coinsInsufficient로 거절하고 아무것도 바꾸지 않는다", async () => {
    await prepareUser({freeCoins: 100, paidCoins: 199});
    const error = await expectHttpsError(() =>
      wrappedChangeNickname(callAs("u1", {nickname: "장기귀신", coinCost: COST})),
    );
    expect(error.details).toEqual({code: "coinsInsufficient"});
    expect(await getWallet("u1")).toMatchObject({freeCoins: 100, paidCoins: 199});
    expect((await db.doc("users/u1").get()).data()?.nickname).toBe("장기신");
    expect((await db.doc("nicknames/장기귀신").get()).exists).toBe(false);
    expect((await db.doc("users_private/u1").get()).data()?.nicknameChangeCount).toBe(1);
  });

  test("응답을 못 받고 다시 불러도 동시에 불러도 한 번만 낸다", async () => {
    await prepareUser({freeCoins: 1000});

    await Promise.all(
      Array.from({length: 3}, (): unknown =>
        wrappedChangeNickname(callAs("u1", {nickname: "장기귀신", coinCost: COST})),
      ),
    );
    await wrappedChangeNickname(callAs("u1", {nickname: "장기귀신", coinCost: COST}));

    expect((await getWallet("u1")).balance).toBe(700);
    expect((await db.doc("users_private/u1").get()).data()?.nicknameChangeCount).toBe(2);
  }, 60000); // 에뮬레이터는 같은 문서를 여러 트랜잭션이 잡으면 잠금이 풀리기를 기다려 오래 걸린다.

  test("coinCost가 잘못된 값이면 invalid-argument", async () => {
    await prepareUser({freeCoins: 1000});
    const error = await expectHttpsError(() =>
      wrappedChangeNickname(callAs("u1", {nickname: "장기귀신", coinCost: "300"})),
    );
    expect(error.code).toBe("invalid-argument");
  });
});

describe("여러 지급이 한꺼번에 오면", () => {
  test("모두 반영하고 잔액이 내역의 합과 맞다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    await setAppConfig({...INITIAL_APP_CONFIG, coinRescueThreshold: 100});
    await db.doc("coin_wallets/u1").update({freeCoins: 40, balance: 40});
    await db.doc("coin_transactions/signup_u1").update({freeDelta: 40, freeBalance: 40});

    await Promise.all([
      wrappedClaimAttendance(callAs("u1")),
      wrappedClaimCoinRescue(callAs("u1")),
      wrappedClaimAttendance(callAs("u1")),
      wrappedClaimCoinRescue(callAs("u1")),
    ]);

    // 구제와 출석 어느 쪽이 먼저 돌아도 40 + 50 + 30이다.
    expect((await getWallet("u1")).balance).toBe(120);
    await expectLedgerConsistent("u1");
  });
});

describe("adminGetCoinStats", () => {
  test("관리자가 아니면 거절한다", async () => {
    const error = await expectHttpsError(() => wrappedGetCoinStats(callAs("u1")));
    expect(error.code).toBe("permission-denied");
  });

  test("잔액 분포와 하루 지표를 센다", async () => {
    await setWallet("a", {freeCoins: 5});
    await setWallet("b", {freeCoins: 10});
    await setWallet("c", {freeCoins: 40, paidCoins: 20});
    await setWallet("d", {paidCoins: 5000});
    const now = Timestamp.now();
    const yesterday = Timestamp.fromMillis(dayjs().subtract(1, "day").valueOf());
    const transaction = {uid: "a", freeDelta: 0, paidDelta: 0, freeBalance: 0, paidBalance: 0, gameId: null};
    await db.collection("coin_transactions").add({...transaction, reason: "timeExtension", createdAt: now});
    await db.collection("coin_transactions").add({...transaction, reason: "timeExtension", createdAt: now});
    await db.collection("coin_transactions").add({...transaction, reason: "gamePractice", createdAt: now});
    await db.collection("coin_transactions").add({...transaction, reason: "rewardedAd", createdAt: yesterday});
    await db.doc("games_archived/g1").set({endedAt: now});

    const stats = await wrappedGetCoinStats(callAs("admin", {}, true));

    expect(stats.balanceBuckets).toEqual([
      {min: 0, max: 10, count: 1},
      {min: 10, max: 50, count: 1},
      {min: 50, max: 100, count: 1},
      {min: 100, max: 300, count: 0},
      {min: 300, max: 1000, count: 0},
      {min: 1000, max: 3000, count: 0},
      {min: 3000, max: null, count: 1},
    ]);
    expect(stats.days).toHaveLength(7);
    expect(stats.days[0]).toEqual({
      day: daysAgo(0),
      games: 1,
      timeExtensions: 2,
      gamePractices: 1,
      rewardedAds: 0,
    });
    expect(stats.days[1]).toEqual({day: daysAgo(1), games: 0, timeExtensions: 0, gamePractices: 0, rewardedAds: 1});
  });
});
