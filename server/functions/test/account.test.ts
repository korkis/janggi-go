import dayjs from "dayjs";
import {deleteApp, getApp, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {Timestamp, getFirestore} from "firebase-admin/firestore";
import functionsTest from "firebase-functions-test";
import {HttpsError} from "firebase-functions/https";
import {adminGetReport} from "../src/callables/adminGetReport";
import {adminResolveReport} from "../src/callables/adminResolveReport";
import {adminRestoreAccount} from "../src/callables/adminRestoreAccount";
import {changeNickname} from "../src/callables/changeNickname";
import {claimAttendance} from "../src/callables/claimAttendance";
import {createProfile} from "../src/callables/createProfile";
import {deleteAccount} from "../src/callables/deleteAccount";
import {sendChatMessage} from "../src/callables/sendChatMessage";
import {ReportWithTargetView, UserHistoryView} from "../src/models/admin";
import {AppConfig, INITIAL_APP_CONFIG} from "../src/models/appConfig";
import {setAppConfig} from "../src/repositories/configsRepository";
import {getRtdb} from "../src/repositories/rtdb";
import {purgeDeletedAccounts as purgeDeletedAccountsWithKey} from "../src/services/accountService";
import {deleteRevenueCatCustomer} from "../src/services/revenueCatApi";
import {TEST_PROJECT_ID} from "./testEnv";

// RevenueCat에 닿지 않게 한다.
jest.mock("../src/services/revenueCatApi");
const deleteRevenueCatCustomerMock = jest.mocked(deleteRevenueCatCustomer);

const REVENUECAT_API_KEY = "test-revenuecat-key";

function purgeDeletedAccounts(): Promise<void> {
  return purgeDeletedAccountsWithKey(REVENUECAT_API_KEY);
}

// defineSecret("OPENAI_API_KEY").value()가 읽는 값.
process.env.OPENAI_API_KEY = "test-openai-key";

const fft = functionsTest({projectId: TEST_PROJECT_ID});
initializeApp({projectId: TEST_PROJECT_ID});
const db = getFirestore();
const rtdb = getRtdb();

const wrappedDeleteAccount = fft.wrap(deleteAccount);
const wrappedRestore = fft.wrap(adminRestoreAccount);
const wrappedCreateProfile = fft.wrap(createProfile);
const wrappedChangeNickname = fft.wrap(changeNickname);
const wrappedClaimAttendance = fft.wrap(claimAttendance);
const wrappedSendChat = fft.wrap(sendChatMessage);
const wrappedGetReport = fft.wrap(adminGetReport);
const wrappedResolveReport = fft.wrap(adminResolveReport);

const WEB_ORIGIN = "https://janggi-go.web.app";

// fft.wrap은 CallableRequest 전체를 받는다. 테스트에 필요한 필드만 채운다.
function callAs(uid: string, data: unknown = {}, {admin = false, origin}: {admin?: boolean; origin?: string} = {}) {
  return {
    data,
    auth: {uid, token: {uid, admin}},
    rawRequest: {headers: origin === undefined ? {} : {origin}},
    acceptsStreaming: false,
  } as never;
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

function getCode(error: HttpsError): unknown {
  return (error.details as {code?: unknown} | undefined)?.code;
}

async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${TEST_PROJECT_ID}/databases/(default)/documents`, {
    method: "DELETE",
  });
}

async function clearAuth(): Promise<void> {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${TEST_PROJECT_ID}/accounts`, {method: "DELETE"});
}

async function createAuthUser(uid: string): Promise<void> {
  await getAuth().createUser({uid, email: `${uid}@example.com`, password: "password123"});
}

/** Auth 계정과 프로필, 지갑, 레이팅, 활동 상태를 만든다. */
async function createAccount(uid: string, nickname: string, sanction: unknown = null): Promise<void> {
  await createAuthUser(uid);
  const now = Timestamp.now();
  await db.doc(`users/${uid}`).set({
    nickname,
    rankLevel: 1,
    stats: {games: 0, wins: 0, losses: 0},
    createdAt: now,
  });
  await db.doc(`users_private/${uid}`).set({
    challengesEnabled: true,
    rankProgress: 0,
    winsToNextRank: null,
    nicknameChangeCount: 0,
    nicknameChangedAt: null,
    sanction,
  });
  await db.doc(`nicknames/${nickname.toLowerCase()}`).set({uid, createdAt: now});
  await db.doc(`coin_wallets/${uid}`).set({
    freeCoins: 300,
    paidCoins: 0,
    balance: 300,
    attendanceDay: null,
    attendanceStreak: 0,
    updatedAt: now,
  });
  await db.doc(`ratings/${uid}`).set({rating: 1000, ratedGames: 0, updatedAt: now});
  await db.doc(`player_states/${uid}`).set({gameId: null, roomId: null, updatedAt: now});
}

async function getData(path: string): Promise<FirebaseFirestore.DocumentData | undefined> {
  return (await db.doc(path).get()).data();
}

async function setConfig(changes: Partial<AppConfig>): Promise<void> {
  await setAppConfig({...INITIAL_APP_CONFIG, ...changes});
}

/** 탈퇴를 [days]일 전에 누른 것으로 만든다. */
async function backdateDeletion(uid: string, days: number): Promise<void> {
  await db.doc(`users/${uid}`).update({deletedAt: Timestamp.fromDate(dayjs().subtract(days, "day").toDate())});
}

beforeEach(async () => {
  await clearFirestore();
  await clearAuth();
  await rtdb.ref().update({"connections/me": null, "online_users/me": null, chats_lobby: null});
  await setConfig({});
});

afterAll(async () => {
  fft.cleanup();
  await deleteApp(getApp());
});

describe("deleteAccount", () => {
  test("표시하고 Auth 계정을 비활성화하며 접속 기록을 지운다. 나머지는 그대로 둔다", async () => {
    await createAccount("me", "장기왕");
    await rtdb.ref("connections/me/c1").set({online: true});
    await rtdb.ref("online_users/me").set({nickname: "장기왕"});

    await wrappedDeleteAccount(callAs("me"));

    expect((await getData("users/me"))?.deletedAt).toBeInstanceOf(Timestamp);
    expect((await getAuth().getUser("me")).disabled).toBe(true);
    expect((await rtdb.ref("connections/me").get()).exists()).toBe(false);
    expect((await rtdb.ref("online_users/me").get()).exists()).toBe(false);
    expect(await getData("coin_wallets/me")).toBeDefined();
    expect(await getData("nicknames/장기왕")).toEqual(expect.objectContaining({uid: "me"}));
  });

  test("다시 불러도 처음 누른 시각을 바꾸지 않고 비활성화까지 이어 간다", async () => {
    await createAccount("me", "장기왕");
    await backdateDeletion("me", 3);
    const firstDeletedAt = (await getData("users/me"))?.deletedAt as Timestamp;

    await wrappedDeleteAccount(callAs("me"));

    expect(((await getData("users/me"))?.deletedAt as Timestamp).isEqual(firstDeletedAt)).toBe(true);
    expect((await getAuth().getUser("me")).disabled).toBe(true);
  });

  test("대국 중이면 inGame으로 거절하고 아무것도 바꾸지 않는다", async () => {
    await createAccount("me", "장기왕");
    await db.doc("player_states/me").update({gameId: "g1"});

    const error = await expectHttpsError(() => wrappedDeleteAccount(callAs("me")));

    expect(getCode(error)).toBe("inGame");
    expect((await getData("users/me"))?.deletedAt).toBeUndefined();
    expect((await getAuth().getUser("me")).disabled).toBe(false);
  });

  test.each([
    ["방", {roomId: "r1"}],
    ["대기열", {quickQueueJoinedAt: Timestamp.now()}],
    ["보낸 신청", {outgoingChallengeId: "c1"}],
    ["받은 신청", {incomingChallengeId: "c1"}],
  ])("%s에 남아 있으면 busy로 거절한다", async (_, state) => {
    await createAccount("me", "장기왕");
    await db.doc("player_states/me").update(state);

    const error = await expectHttpsError(() => wrappedDeleteAccount(callAs("me")));

    expect(getCode(error)).toBe("busy");
    expect((await getData("users/me"))?.deletedAt).toBeUndefined();
  });

  test("닉네임을 정하기 전이면 Auth 계정을 바로 지운다", async () => {
    await createAuthUser("me");

    await wrappedDeleteAccount(callAs("me"));

    await expect(getAuth().getUser("me")).rejects.toMatchObject({code: "auth/user-not-found"});
  });

  test("탈퇴한 사용자의 채팅과 닉네임 변경을 막는다", async () => {
    await createAccount("me", "장기왕");
    await wrappedDeleteAccount(callAs("me"));

    const chatError = await expectHttpsError(() => wrappedSendChat(callAs("me", {channel: "lobby", text: "안녕"})));
    const nicknameError = await expectHttpsError(() => wrappedChangeNickname(callAs("me", {nickname: "장기신"})));

    expect(getCode(chatError)).toBe("profileRequired");
    expect(getCode(nicknameError)).toBe("profileRequired");
  });
});

describe("adminRestoreAccount", () => {
  test("표시를 지우고 Auth 계정을 다시 켠다", async () => {
    await createAccount("me", "장기왕");
    await wrappedDeleteAccount(callAs("me"));

    const history = (await wrappedRestore(
      callAs("admin", {uid: "me", reason: "실수로 탈퇴"}, {admin: true}),
    )) as UserHistoryView;

    expect(history.profile?.deletedAt).toBeNull();
    expect((await getData("users/me"))?.deletedAt).toBeNull();
    expect((await getAuth().getUser("me")).disabled).toBe(false);
    expect(await getData("nicknames/장기왕")).toBeDefined();
  });

  test("되돌린 사람은 30일이 지나도 지우지 않는다", async () => {
    await createAccount("me", "장기왕");
    await wrappedDeleteAccount(callAs("me"));
    await wrappedRestore(callAs("admin", {uid: "me", reason: "실수로 탈퇴"}, {admin: true}));

    await purgeDeletedAccounts();

    expect(await getData("users/me")).toBeDefined();
  });

  test("탈퇴하지 않았으면 notDeleted, 없으면 notFound, 관리자가 아니면 거절한다", async () => {
    await createAccount("me", "장기왕");

    const notDeleted = await expectHttpsError(() =>
      wrappedRestore(callAs("admin", {uid: "me", reason: "사유"}, {admin: true})),
    );
    const notFound = await expectHttpsError(() =>
      wrappedRestore(callAs("admin", {uid: "nobody", reason: "사유"}, {admin: true})),
    );
    const denied = await expectHttpsError(() => wrappedRestore(callAs("me", {uid: "me", reason: "사유"})));

    expect(getCode(notDeleted)).toBe("notDeleted");
    expect(getCode(notFound)).toBe("notFound");
    expect(denied.code).toBe("permission-denied");
  });
});

describe("purgeDeletedAccounts", () => {
  beforeEach(() => {
    deleteRevenueCatCustomerMock.mockClear();
  });

  /** 지우고 남기는 것을 모두 확인할 탈퇴자와 관련 기록을 만든다. */
  async function createDeletedAccountWithRecords(): Promise<void> {
    await createAccount("me", "장기왕");
    await createAccount("other", "상대");
    const now = Timestamp.now();
    await db.doc("users/me/blocks/other").set({createdAt: now});
    await db.doc("users/other/blocks/me").set({createdAt: now});
    await db.collection("nickname_changes").add({uid: "me", before: "옛이름", after: "장기왕", changedAt: now});
    await db.doc("coin_transactions/signup_me").set({uid: "me", reason: "signup", createdAt: now});
    await db.doc("coin_transactions/signup_other").set({uid: "other", reason: "signup", createdAt: now});
    await db
      .doc("inventories/me")
      .set({materials: ["wood"], selectedMaterial: "wood", adsRemoved: true, updatedAt: now});
    await db
      .doc("inventories/other")
      .set({materials: [], selectedMaterial: "plastic", adsRemoved: true, updatedAt: now});
    await db
      .doc("purchases/PLAY_STORE_T1")
      .set({uid: "me", productId: "pieces_wood", status: "granted", createdAt: now});
    await db
      .doc("purchases/PLAY_STORE_T2")
      .set({uid: "other", productId: "remove_ads", status: "granted", createdAt: now});
    await db.doc("sanctions/s1").set({
      uid: "me",
      type: "warning",
      startsAt: now,
      endsAt: null,
      reason: "욕설",
      reportId: null,
      adminUid: "admin",
      createdAt: now,
    });
    await db.doc("rooms/r1").set({hostUid: "me", status: "closed"});
    await db.doc("rooms/r2").set({hostUid: "other", status: "waiting"});
    await db.doc("challenges/c1").set({fromUid: "me", toUid: "other", status: "expired"});
    await db.doc("challenges/c2").set({fromUid: "other", toUid: "me", status: "declined"});
    await db.doc("challenges/c3").set({fromUid: "other", toUid: "third", status: "declined"});
    await db.doc("games_archived/g1").set({playerUids: ["me", "other"], pairKey: "me_other"});
    await db.doc("reports/m1_other").set({reporterUid: "other", targetUid: "me", status: "pending"});
    await wrappedDeleteAccount(callAs("me"));
  }

  test("30일 지난 사람의 데이터를 지우고 남길 기록은 남긴다", async () => {
    await createDeletedAccountWithRecords();
    await backdateDeletion("me", 30);

    await purgeDeletedAccounts();

    for (const path of [
      "users/me",
      "users/me/blocks/other",
      "users_private/me",
      "coin_wallets/me",
      "inventories/me",
      "ratings/me",
      "player_states/me",
      "nicknames/장기왕",
      "rooms/r1",
      "challenges/c1",
      "challenges/c2",
    ]) {
      expect(await getData(path)).toBeUndefined();
    }
    await expect(getAuth().getUser("me")).rejects.toMatchObject({code: "auth/user-not-found"});
    expect((await db.collection("nickname_changes").where("uid", "==", "me").get()).empty).toBe(true);

    // 남기는 것.
    expect(await getData("games_archived/g1")).toBeDefined();
    expect(await getData("reports/m1_other")).toBeDefined();
    expect(await getData("users/other/blocks/me")).toBeDefined();
    const coinExpiresAt = (await getData("coin_transactions/signup_me"))?.expiresAt as Timestamp;
    const sanctionExpiresAt = (await getData("sanctions/s1"))?.expiresAt as Timestamp;
    expect(dayjs(coinExpiresAt.toDate()).diff(dayjs(), "year", true)).toBeCloseTo(5, 1);
    const purchaseExpiresAt = (await getData("purchases/PLAY_STORE_T1"))?.expiresAt as Timestamp;
    expect(dayjs(purchaseExpiresAt.toDate()).diff(dayjs(), "year", true)).toBeCloseTo(5, 1);
    expect(deleteRevenueCatCustomerMock).toHaveBeenCalledTimes(1);
    expect(deleteRevenueCatCustomerMock).toHaveBeenCalledWith("me", REVENUECAT_API_KEY);
    expect(dayjs(sanctionExpiresAt.toDate()).diff(dayjs(), "day")).toBeGreaterThanOrEqual(364);

    // 다른 사람의 것은 건드리지 않는다.
    for (const path of ["users/other", "nicknames/상대", "rooms/r2", "challenges/c3", "inventories/other"]) {
      expect(await getData(path)).toBeDefined();
    }
    expect((await getData("coin_transactions/signup_other"))?.expiresAt).toBeUndefined();
    expect((await getData("purchases/PLAY_STORE_T2"))?.expiresAt).toBeUndefined();

    // 남은 제재가 없으므로 재가입을 막는 기록을 남기지 않는다.
    expect((await db.collection("deleted_accounts").get()).empty).toBe(true);
  });

  test("RevenueCat 고객을 지우지 못하면 사람을 지우지 않고 다음에 다시 한다", async () => {
    await createDeletedAccountWithRecords();
    await backdateDeletion("me", 30);
    deleteRevenueCatCustomerMock.mockRejectedValueOnce(new Error("RevenueCat 장애"));

    await purgeDeletedAccounts();
    expect(await getData("users/me")).toBeDefined();
    expect(await getData("inventories/me")).toBeDefined();
    expect((await getAuth().getUser("me")).uid).toBe("me");

    await purgeDeletedAccounts();
    expect(await getData("users/me")).toBeUndefined();
    expect(await getData("inventories/me")).toBeUndefined();
  });

  test("30일이 지나지 않았으면 지우지 않는다", async () => {
    await createDeletedAccountWithRecords();
    await backdateDeletion("me", 29);

    await purgeDeletedAccounts();

    expect(await getData("users/me")).toBeDefined();
    expect((await getAuth().getUser("me")).disabled).toBe(true);
  });

  test("지운 닉네임은 다른 사람이 쓸 수 있고, 지운 계정은 새 사용자로 다시 가입한다", async () => {
    await createAccount("me", "장기왕");
    await wrappedDeleteAccount(callAs("me"));
    await backdateDeletion("me", 31);
    await purgeDeletedAccounts();

    await createAuthUser("me2");
    await wrappedCreateProfile(callAs("me2", {nickname: "장기왕"}));

    expect((await getData("users/me2"))?.nickname).toBe("장기왕");
    expect((await getData("coin_wallets/me2"))?.balance).toBe(INITIAL_APP_CONFIG.coinSignupBonus);
  });

  describe("제재가 남은 계정", () => {
    /** 같은 이메일로 새 uid의 Auth 계정을 만든다. 지운 계정으로 다시 가입한 것과 같다. */
    async function signUpAgain(): Promise<void> {
      await getAuth().createUser({uid: "me2", email: "me@example.com", password: "password123"});
    }

    async function purgeSanctioned(sanction: unknown): Promise<void> {
      await createAccount("me", "장기왕", sanction);
      await wrappedDeleteAccount(callAs("me"));
      await backdateDeletion("me", 31);
      await purgeDeletedAccounts();
    }

    test("영구 정지면 다시 가입할 수 없다", async () => {
      await purgeSanctioned({type: "permanentBan", endsAt: null, reason: "욕설"});
      await signUpAgain();

      const error = await expectHttpsError(() => wrappedCreateProfile(callAs("me2", {nickname: "새이름"})));

      expect(getCode(error)).toBe("signupBlocked");
      expect(await getData("users/me2")).toBeUndefined();
      const [record] = (await db.collection("deleted_accounts").get()).docs;
      expect(record?.data().expiresAt).toBeNull();
      expect(record?.id).not.toContain("example.com");
    });

    test("기간 제재는 끝날 때까지 막고 끝나면 받는다", async () => {
      const endsAt = Timestamp.fromDate(dayjs().add(7, "day").toDate());
      await purgeSanctioned({type: "suspension", endsAt, reason: "욕설"});
      await signUpAgain();

      const error = await expectHttpsError(() => wrappedCreateProfile(callAs("me2", {nickname: "새이름"})));
      expect(getCode(error)).toBe("signupBlocked");

      const [record] = (await db.collection("deleted_accounts").get()).docs;
      expect((record?.data().expiresAt as Timestamp).isEqual(endsAt)).toBe(true);
      await record?.ref.update({expiresAt: Timestamp.fromDate(dayjs().subtract(1, "minute").toDate())});

      await wrappedCreateProfile(callAs("me2", {nickname: "새이름"}));
      expect((await getData("users/me2"))?.nickname).toBe("새이름");
    });

    test("경고와 끝난 제재는 기록을 남기지 않는다", async () => {
      await purgeSanctioned({type: "warning", endsAt: null, reason: "욕설"});
      expect((await db.collection("deleted_accounts").get()).empty).toBe(true);
    });
  });

  test("지운 사용자의 처리 전 신고를 열고 처리할 수 있다. 제재는 이력에만 남는다", async () => {
    await createDeletedAccountWithRecords();
    await backdateDeletion("me", 31);
    await purgeDeletedAccounts();
    const now = dayjs().valueOf();
    await db.doc("reports/m1_other").set({
      reporterUid: "other",
      targetUid: "me",
      channel: "lobby",
      gameId: null,
      message: {messageId: "m1", uid: "me", nickname: "장기왕", text: "바보", sentAt: now},
      context: [],
      check: null,
      status: "pending",
      resolution: null,
      createdAt: Timestamp.now(),
      resolvedAt: null,
      expiresAt: null,
    });

    const detail = (await wrappedGetReport(
      callAs("admin", {reportId: "m1_other"}, {admin: true}),
    )) as ReportWithTargetView;
    expect(detail.target.profile).toBeNull();

    const resolved = (await wrappedResolveReport(
      callAs("admin", {reportId: "m1_other", action: "warning", reason: "욕설"}, {admin: true}),
    )) as ReportWithTargetView;

    expect(resolved.report.status).toBe("resolved");
    expect(await getData("users_private/me")).toBeUndefined();
    const sanctions = await db.collection("sanctions").where("reportId", "==", "m1_other").get();
    expect(sanctions.docs[0]?.data().expiresAt).toBeInstanceOf(Timestamp);
  });
});

describe("운영 스위치", () => {
  test("signupEnabled를 끄면 새 가입만 막는다", async () => {
    await createAccount("old", "기존사람");
    await createAuthUser("new");
    await setConfig({signupEnabled: false});

    const error = await expectHttpsError(() => wrappedCreateProfile(callAs("new", {nickname: "새사람"})));

    expect(getCode(error)).toBe("featureDisabled");
    expect(await getData("users/new")).toBeUndefined();
    // 기존 사용자는 그대로다. 응답을 못 받고 다시 부른 가입도 성공이다.
    await wrappedCreateProfile(callAs("old", {nickname: "기존사람"}));
    await wrappedChangeNickname(callAs("old", {nickname: "바꾼사람"}));
    expect((await getData("users/old"))?.nickname).toBe("바꾼사람");
  });

  test("chatEnabled를 끄면 채팅을 거절한다", async () => {
    await createAccount("me", "장기왕");
    await setConfig({chatEnabled: false});

    const error = await expectHttpsError(() => wrappedSendChat(callAs("me", {channel: "lobby", text: "안녕"})));

    expect(getCode(error)).toBe("featureDisabled");
    expect((await rtdb.ref("chats_lobby").get()).exists()).toBe(false);
  });

  test("webEnabled를 끄면 웹에서 온 호출만 거절한다. 탈퇴는 받는다", async () => {
    await createAccount("me", "장기왕");
    await setConfig({webEnabled: false});

    const webError = await expectHttpsError(() => wrappedClaimAttendance(callAs("me", {}, {origin: WEB_ORIGIN})));
    expect(getCode(webError)).toBe("featureDisabled");
    const profileError = await expectHttpsError(() =>
      wrappedCreateProfile(callAs("me", {nickname: "장기왕"}, {origin: WEB_ORIGIN})),
    );
    expect(getCode(profileError)).toBe("featureDisabled");

    await expect(wrappedClaimAttendance(callAs("me"))).resolves.toMatchObject({granted: true});
    await wrappedDeleteAccount(callAs("me", {}, {origin: WEB_ORIGIN}));
    expect((await getData("users/me"))?.deletedAt).toBeInstanceOf(Timestamp);
  });

  test("webEnabled가 켜져 있으면 웹에서 온 호출을 받는다", async () => {
    await createAccount("me", "장기왕");

    await expect(wrappedClaimAttendance(callAs("me", {}, {origin: WEB_ORIGIN}))).resolves.toMatchObject({
      granted: true,
    });
  });
});
