import {initializeApp} from "firebase-admin/app";
import {Timestamp, getFirestore} from "firebase-admin/firestore";
import functionsTest from "firebase-functions-test";
import {HttpsError} from "firebase-functions/https";
import {changeNickname} from "../src/callables/changeNickname";
import {checkNickname} from "../src/callables/checkNickname";
import {createProfile} from "../src/callables/createProfile";
import {INITIAL_APP_CONFIG} from "../src/models/appConfig";
import {NicknameChange} from "../src/models/nickname";
import {setAppConfig} from "../src/repositories/configsRepository";
import {TEST_PROJECT_ID} from "./testEnv";

const fft = functionsTest({projectId: TEST_PROJECT_ID});
initializeApp({projectId: TEST_PROJECT_ID});
const db = getFirestore();

const wrappedCheckNickname = fft.wrap(checkNickname);
const wrappedCreateProfile = fft.wrap(createProfile);
const wrappedChangeNickname = fft.wrap(changeNickname);

// fft.wrap은 CallableRequest 전체를 받는다. 테스트에 필요한 필드만 채운다.
function callAs(uid: string | null, data: unknown) {
  return {
    data,
    auth: uid === null ? undefined : {uid, token: {uid}},
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

/** [call]이 HttpsError로 실패하는지 보고 그 오류를 돌려준다. */
async function expectHttpsError(call: () => unknown): Promise<HttpsError> {
  try {
    await call();
  } catch (error) {
    expect(error).toBeInstanceOf(HttpsError);
    return error as HttpsError;
  }
  throw new Error("HttpsError로 실패해야 한다");
}

beforeEach(async () => {
  await clearFirestore();
  await setAppConfig(INITIAL_APP_CONFIG);
});

afterAll(() => {
  fft.cleanup();
});

describe("checkNickname", () => {
  test("쓸 수 있는 닉네임", async () => {
    await expect(wrappedCheckNickname(callAs("u1", {nickname: "장기왕"}))).resolves.toEqual({
      available: true,
      reason: null,
    });
  });

  test.each([
    ["가", "invalidFormat"],
    ["열한글자가넘는닉네임이다", "invalidFormat"],
    ["장기 왕", "invalidFormat"],
    ["ㅈㄱ왕", "invalidFormat"],
    ["장기왕!", "invalidFormat"],
    ["운영자김씨", "impersonation"],
    ["ADMIN1", "impersonation"],
    ["병신왕", "bannedWord"],
    ["FuckYou", "bannedWord"],
  ])("%s는 %s", async (nickname, reason) => {
    await expect(wrappedCheckNickname(callAs("u1", {nickname}))).resolves.toEqual({available: false, reason});
  });

  test("영문 대소문자만 다른 닉네임은 이미 쓰는 것으로 본다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "King"}));
    await expect(wrappedCheckNickname(callAs("u2", {nickname: "kING"}))).resolves.toEqual({
      available: false,
      reason: "taken",
    });
  });

  test("로그인하지 않으면 거절한다", async () => {
    const error = await expectHttpsError(() => wrappedCheckNickname(callAs(null, {nickname: "장기왕"})));
    expect(error.code).toBe("unauthenticated");
  });

  test("nickname이 문자열이 아니면 거절한다", async () => {
    const error = await expectHttpsError(() => wrappedCheckNickname(callAs("u1", {nickname: 3})));
    expect(error.code).toBe("invalid-argument");
  });
});

describe("createProfile", () => {
  test("nicknames, users, users_private를 만든다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));

    const user = (await db.doc("users/u1").get()).data();
    expect(user).toMatchObject({nickname: "장기왕", rankLevel: 1, stats: {games: 0, wins: 0, losses: 0}});
    expect(user?.createdAt).toBeDefined();
    const userPrivate = (await db.doc("users_private/u1").get()).data();
    expect(userPrivate).toEqual({
      challengesEnabled: true,
      rankProgress: 0,
      winsToNextRank: null,
      nicknameChangeCount: 0,
      nicknameChangedAt: null,
      sanction: null,
    });
    expect((await db.doc("nicknames/장기왕").get()).data()?.uid).toBe("u1");
  });

  test("영문 닉네임은 소문자 키로 예약한다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "King"}));
    expect((await db.doc("nicknames/king").get()).data()?.uid).toBe("u1");
    expect((await db.doc("users/u1").get()).data()?.nickname).toBe("King");
  });

  test("다른 사람이 쓰는 닉네임이면 taken으로 거절한다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    const error = await expectHttpsError(() => wrappedCreateProfile(callAs("u2", {nickname: "장기왕"})));
    expect(error.code).toBe("already-exists");
    expect(error.details).toEqual({code: "taken"});
    expect((await db.doc("users/u2").get()).exists).toBe(false);
  });

  test("같은 닉네임으로 다시 부르면 성공으로 본다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    await expect(wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}))).resolves.toEqual({});
  });

  test("이미 프로필이 있으면 다른 닉네임으로 만들지 못한다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    const error = await expectHttpsError(() => wrappedCreateProfile(callAs("u1", {nickname: "장기신"})));
    expect(error.code).toBe("failed-precondition");
    expect(error.details).toEqual({code: "profileExists"});
    expect((await db.doc("nicknames/장기신").get()).exists).toBe(false);
  });

  test("쓸 수 없는 닉네임은 이유를 담아 거절한다", async () => {
    const error = await expectHttpsError(() => wrappedCreateProfile(callAs("u1", {nickname: "운영자"})));
    expect(error.code).toBe("invalid-argument");
    expect(error.details).toEqual({code: "impersonation"});
  });

  test("로그인하지 않으면 거절한다", async () => {
    const error = await expectHttpsError(() => wrappedCreateProfile(callAs(null, {nickname: "장기왕"})));
    expect(error.code).toBe("unauthenticated");
  });
});

describe("changeNickname", () => {
  /** 닉네임 변경 기록. 바뀐 순서대로다. */
  async function getChanges(uid: string) {
    const snapshot = await db.collection("nickname_changes").where("uid", "==", uid).get();
    return snapshot.docs
      .map((document) => document.data() as NicknameChange)
      .sort((a, b) => a.changedAt.toMillis() - b.changedAt.toMillis());
  }

  test("첫 변경은 예약을 옮기고 횟수와 시각, 변경 기록을 남긴다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    await expect(wrappedChangeNickname(callAs("u1", {nickname: "장기신"}))).resolves.toEqual({});

    const user = (await db.doc("users/u1").get()).data();
    expect(user).toMatchObject({nickname: "장기신", rankLevel: 1, stats: {games: 0, wins: 0, losses: 0}});
    const userPrivate = (await db.doc("users_private/u1").get()).data();
    expect(userPrivate?.nicknameChangeCount).toBe(1);
    expect(userPrivate?.nicknameChangedAt).toBeInstanceOf(Timestamp);
    expect((await db.doc("nicknames/장기왕").get()).exists).toBe(false);
    expect((await db.doc("nicknames/장기신").get()).data()?.uid).toBe("u1");
    const changes = await getChanges("u1");
    expect(changes).toHaveLength(1);
    expect(changes[0]).toMatchObject({uid: "u1", before: "장기왕", after: "장기신"});

    // 이전 닉네임은 다른 사람이 쓸 수 있다.
    await expect(wrappedCheckNickname(callAs("u2", {nickname: "장기왕"}))).resolves.toEqual({
      available: true,
      reason: null,
    });
  });

  test("영문 대소문자만 바꾸면 같은 예약을 그대로 쓴다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "King"}));
    await wrappedChangeNickname(callAs("u1", {nickname: "KING"}));
    expect((await db.doc("users/u1").get()).data()?.nickname).toBe("KING");
    expect((await db.doc("nicknames/king").get()).data()?.uid).toBe("u1");
  });

  test("지금 닉네임과 같으면 바꾸지 않고 성공으로 본다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    await wrappedChangeNickname(callAs("u1", {nickname: "장기신"}));
    await expect(wrappedChangeNickname(callAs("u1", {nickname: "장기신"}))).resolves.toEqual({});
    expect((await db.doc("users_private/u1").get()).data()?.nicknameChangeCount).toBe(1);
    expect(await getChanges("u1")).toHaveLength(1);
  });

  test("바꾼 지 7일이 지나지 않았으면 거절한다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    await wrappedChangeNickname(callAs("u1", {nickname: "장기신"}));
    const error = await expectHttpsError(() => wrappedChangeNickname(callAs("u1", {nickname: "장기귀신"})));
    expect(error.code).toBe("failed-precondition");
    expect(error.details).toEqual({code: "nicknameChangeCooldown"});
    expect((await db.doc("users/u1").get()).data()?.nickname).toBe("장기신");
  });

  test("7일이 지나도 무료 변경을 이미 썼으면 거절한다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    await wrappedChangeNickname(callAs("u1", {nickname: "장기신"}));
    await db.doc("users_private/u1").update({nicknameChangedAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z"))});
    const error = await expectHttpsError(() => wrappedChangeNickname(callAs("u1", {nickname: "장기귀신"})));
    expect(error.code).toBe("failed-precondition");
    expect(error.details).toEqual({code: "nicknameChangeNotFree"});
    expect((await db.doc("nicknames/장기귀신").get()).exists).toBe(false);
    // 값을 모르고 부른 옛 앱은 엽전을 내지 않는다.
    expect((await db.doc("coin_wallets/u1").get()).data()?.balance).toBe(INITIAL_APP_CONFIG.coinSignupBonus);
  });

  test("다른 사람이 쓰는 닉네임이면 taken으로 거절한다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    await wrappedCreateProfile(callAs("u2", {nickname: "장기신"}));
    const error = await expectHttpsError(() => wrappedChangeNickname(callAs("u1", {nickname: "장기신"})));
    expect(error.code).toBe("already-exists");
    expect(error.details).toEqual({code: "taken"});
    expect((await db.doc("users_private/u1").get()).data()?.nicknameChangeCount).toBe(0);
    expect((await db.doc("nicknames/장기왕").get()).data()?.uid).toBe("u1");
  });

  test("쓸 수 없는 닉네임은 이유를 담아 거절한다", async () => {
    await wrappedCreateProfile(callAs("u1", {nickname: "장기왕"}));
    const error = await expectHttpsError(() => wrappedChangeNickname(callAs("u1", {nickname: "병신왕"})));
    expect(error.code).toBe("invalid-argument");
    expect(error.details).toEqual({code: "bannedWord"});
  });

  test("프로필이 없으면 profileRequired로 거절한다", async () => {
    const error = await expectHttpsError(() => wrappedChangeNickname(callAs("u1", {nickname: "장기왕"})));
    expect(error.code).toBe("failed-precondition");
    expect(error.details).toEqual({code: "profileRequired"});
    expect((await db.doc("nicknames/장기왕").get()).exists).toBe(false);
  });

  test("로그인하지 않으면 거절한다", async () => {
    const error = await expectHttpsError(() => wrappedChangeNickname(callAs(null, {nickname: "장기왕"})));
    expect(error.code).toBe("unauthenticated");
  });
});
