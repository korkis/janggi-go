import dayjs from "dayjs";
import {deleteApp, getApp, initializeApp} from "firebase-admin/app";
import {Timestamp, getFirestore} from "firebase-admin/firestore";
import functionsTest from "firebase-functions-test";
import {HttpsError} from "firebase-functions/https";
import {reportMessage} from "../src/callables/reportMessage";
import {sendChatMessage} from "../src/callables/sendChatMessage";
import {getRtdb} from "../src/repositories/rtdb";
import {hasBannedWord} from "../src/services/bannedWordService";
import {cleanupChats} from "../src/services/chatCleanupService";
import {ModerationApiError, moderateWithOpenAi} from "../src/services/openAiModeration";
import {TEST_PROJECT_ID} from "./testEnv";

// 네트워크에 흔들리지 않도록 OpenAI Moderation 호출을 가짜로 바꾼다. 실제 검사는 에뮬레이터에서 따로 확인한다.
jest.mock("../src/services/openAiModeration", () => {
  const actual = jest.requireActual<typeof import("../src/services/openAiModeration")>(
    "../src/services/openAiModeration",
  );
  return {...actual, moderateWithOpenAi: jest.fn()};
});
const mockedModerate = jest.mocked(moderateWithOpenAi);

// defineSecret("OPENAI_API_KEY").value()가 읽는 값.
process.env.OPENAI_API_KEY = "test-openai-key";

const fft = functionsTest({projectId: TEST_PROJECT_ID});
initializeApp({projectId: TEST_PROJECT_ID});
const db = getFirestore();
const rtdb = getRtdb();

const wrappedSend = fft.wrap(sendChatMessage);
const wrappedReport = fft.wrap(reportMessage);

const PASSED = {flagged: false, categories: [], scores: {harassment: 0.01, violence: 0.002}};

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

async function createUser(uid: string, nickname: string, sanction: unknown = null): Promise<void> {
  await db.doc(`users/${uid}`).set({nickname, rankLevel: 1, stats: {games: 0, wins: 0, losses: 0}});
  await db.doc(`users_private/${uid}`).set({challengesEnabled: true, sanction});
}

async function createGame(gameId: string, phase: string): Promise<void> {
  await rtdb.ref(`games_active/${gameId}`).set({
    meta: {players: {cho: {uid: "cho", nickname: "초사람"}, han: {uid: "han", nickname: "한사람"}}},
    state: {phase},
  });
}

async function getValue(path: string): Promise<unknown> {
  return (await rtdb.ref(path).get()).val();
}

beforeEach(async () => {
  await clearFirestore();
  // 띄워 둔 에뮬레이터에서 돌려도 다른 데이터를 지우지 않도록 이 테스트가 쓰는 경로만 지운다.
  await rtdb.ref().update({
    chats_lobby: null,
    chats_game: null,
    chats_spectator: null,
    "games_active/g1": null,
  });
  mockedModerate.mockReset();
  mockedModerate.mockResolvedValue(PASSED);
  await createUser("me", "장기왕");
  await createUser("cho", "초사람");
  await createUser("han", "한사람");
});

afterAll(async () => {
  fft.cleanup();
  await deleteApp(getApp());
});

describe("금칙어", () => {
  test.each([
    ["씨발", true],
    ["씨 발 진짜", true],
    ["시1발", true],
    ["ㅅ ㅂ", true],
    ["ㅂㅅ같이 두네", true],
    ["FUCK", true],
    ["한남충", true],
    ["김치녀", true],
    ["틀딱은 꺼져", true],
    ["느그 애미", true],
    ["니 애미 뒤졌냐", true],
    ["뒤져라", true],
    ["대가리 깨져라", true],
    ["너네 집 찾아간다", true],
    ["니 집 찾아간다", true],
    ["시바", true],
    ["씨빠", true],
    ["ㄲㅈ", true],
    ["ㅗㅗ", true],
    ["닥쳐 이 벌레야", true],
    ["벌레같은 수", true],
    ["시바견 키워요", false],
    ["가방을 뒤져 봐야겠네요", false],
    ["집에 가야겠네요", false],
    ["귀여운 애 미소", false],
    ["아저씨 발이 빠르네요", false],
    ["시발점부터 다시", false],
    ["잘 부탁합니다", false],
    ["마 빠르시네요", false],
    ["미친 수네요", false],
  ])("%s → %s", (text, matched) => {
    expect(hasBannedWord(text)).toBe(matched);
  });
});

describe("sendChatMessage", () => {
  test("검사를 통과하면 로비 채팅과 검사 결과를 쓴다", async () => {
    const result = (await wrappedSend(callAs("me", {channel: "lobby", text: "  잘   부탁합니다\n"}))) as {
      messageId: string;
    };

    expect(mockedModerate).toHaveBeenCalledWith("잘 부탁합니다", "test-openai-key");
    const message = (await getValue(`chats_lobby/${result.messageId}`)) as Record<string, unknown>;
    expect(message).toMatchObject({uid: "me", nickname: "장기왕", text: "잘 부탁합니다"});
    expect(typeof message.sentAt).toBe("number");
    const check = (await db.doc(`chat_checks/${result.messageId}`).get()).data();
    expect(check).toMatchObject({scores: PASSED.scores, bannedWordMatched: false});
    const days = dayjs((check?.expiresAt as Timestamp).toDate()).diff(dayjs(), "day", true);
    expect(Math.round(days)).toBe(90);
  });

  test("금칙어에 걸리면 OpenAI에 보내지 않고 저장하지 않으며 검사 기록을 남긴다", async () => {
    const error = await expectHttpsError(() => wrappedSend(callAs("me", {channel: "lobby", text: "ㅅ ㅂ 뭐야"})));
    expect(error.code).toBe("failed-precondition");
    expect(error.details).toEqual({code: "messageBlocked"});
    expect(mockedModerate).not.toHaveBeenCalled();
    expect(await getValue("chats_lobby")).toBeNull();
    const logs = await db.collection("moderation_logs").get();
    expect(logs.size).toBe(1);
    expect(logs.docs[0].data()).toMatchObject({
      uid: "me",
      channel: "lobby",
      gameId: null,
      text: "ㅅ ㅂ 뭐야",
      categories: [],
      scores: {},
      bannedWordMatched: true,
    });
  });

  test("OpenAI가 걸면 분류와 점수를 검사 기록에 남기고 거절한다", async () => {
    mockedModerate.mockResolvedValue({flagged: true, categories: ["harassment"], scores: {harassment: 0.91}});
    const error = await expectHttpsError(() => wrappedSend(callAs("me", {channel: "lobby", text: "너 정말 바보야"})));
    expect(error.details).toEqual({code: "messageBlocked"});
    expect(await getValue("chats_lobby")).toBeNull();
    const logs = await db.collection("moderation_logs").get();
    expect(logs.docs[0].data()).toMatchObject({
      categories: ["harassment"],
      scores: {harassment: 0.91},
      bannedWordMatched: false,
    });
    const days = dayjs((logs.docs[0].data().expiresAt as Timestamp).toDate()).diff(dayjs(), "day", true);
    expect(Math.round(days)).toBe(365);
    expect((await db.collection("chat_checks").get()).size).toBe(0);
  });

  test("OpenAI를 부르지 못하면 저장하지 않고 moderationUnavailable로 거절한다", async () => {
    mockedModerate.mockRejectedValue(new ModerationApiError("권한 없음", 401));
    const error = await expectHttpsError(() => wrappedSend(callAs("me", {channel: "lobby", text: "안녕하세요"})));
    expect(error.code).toBe("unavailable");
    expect(error.details).toEqual({code: "moderationUnavailable"});
    expect(await getValue("chats_lobby")).toBeNull();
    expect((await db.collection("moderation_logs").get()).size).toBe(0);
  });

  test("닉네임을 정하지 않았으면 profileRequired", async () => {
    const error = await expectHttpsError(() => wrappedSend(callAs("nobody", {channel: "lobby", text: "안녕"})));
    expect(error.details).toEqual({code: "profileRequired"});
  });

  test("채팅 제한과 이용 정지는 막고, 경고와 끝난 제재는 막지 않는다", async () => {
    const future = Timestamp.fromDate(dayjs().add(1, "day").toDate());
    const past = Timestamp.fromDate(dayjs().subtract(1, "minute").toDate());

    await createUser("me", "장기왕", {type: "chatRestriction", endsAt: future, reason: "욕설"});
    let error = await expectHttpsError(() => wrappedSend(callAs("me", {channel: "lobby", text: "안녕"})));
    expect(error.details).toEqual({code: "chatRestricted"});

    await createUser("me", "장기왕", {type: "permanentBan", endsAt: null, reason: "욕설"});
    error = await expectHttpsError(() => wrappedSend(callAs("me", {channel: "lobby", text: "안녕"})));
    expect(error.details).toEqual({code: "sanctioned"});

    await createUser("me", "장기왕", {type: "chatRestriction", endsAt: past, reason: "욕설"});
    await expect(wrappedSend(callAs("me", {channel: "lobby", text: "안녕"}))).resolves.toHaveProperty("messageId");

    await createUser("me", "장기왕", {type: "warning", endsAt: null, reason: "욕설"});
    await expect(wrappedSend(callAs("me", {channel: "lobby", text: "안녕"}))).resolves.toHaveProperty("messageId");
  });

  test("대국 채팅은 두 대국자만 쓴다", async () => {
    await createGame("g1", "playing");
    const result = (await wrappedSend(callAs("cho", {channel: "game", gameId: "g1", text: "잘 부탁드립니다"}))) as {
      messageId: string;
    };
    expect(await getValue(`chats_game/g1/${result.messageId}/nickname`)).toBe("초사람");

    let error = await expectHttpsError(() => wrappedSend(callAs("me", {channel: "game", gameId: "g1", text: "훈수"})));
    expect(error.details).toEqual({code: "notAllowed"});
    error = await expectHttpsError(() => wrappedSend(callAs("cho", {channel: "game", gameId: "g2", text: "안녕"})));
    expect(error.details).toEqual({code: "notFound"});
  });

  test("관전 채팅은 대국 중인 대국자만 막는다", async () => {
    await createGame("g1", "playing");
    await expect(
      wrappedSend(callAs("me", {channel: "spectator", gameId: "g1", text: "좋은 수네요"})),
    ).resolves.toHaveProperty("messageId");
    const error = await expectHttpsError(() =>
      wrappedSend(callAs("han", {channel: "spectator", gameId: "g1", text: "고마워요"})),
    );
    expect(error.details).toEqual({code: "notAllowed"});

    await createGame("g1", "finished");
    await expect(
      wrappedSend(callAs("han", {channel: "spectator", gameId: "g1", text: "응원 고마워요"})),
    ).resolves.toHaveProperty("messageId");
  });

  test.each([
    ["채팅 종류가 틀림", {channel: "room", text: "안녕"}],
    ["로비 채팅에 대국 ID", {channel: "lobby", gameId: "g1", text: "안녕"}],
    ["대국 채팅에 대국 ID 없음", {channel: "game", text: "안녕"}],
    ["경로를 벗어나는 대국 ID", {channel: "game", gameId: "g1/../x", text: "안녕"}],
    ["빈 메시지", {channel: "lobby", text: "   "}],
    ["너무 긴 메시지", {channel: "lobby", text: "가".repeat(101)}],
    ["text가 문자열이 아님", {channel: "lobby", text: 3}],
  ])("%s이면 invalid-argument", async (_, data) => {
    const error = await expectHttpsError(() => wrappedSend(callAs("me", data)));
    expect(error.code).toBe("invalid-argument");
  });

  test("100자는 보낸다", async () => {
    await expect(wrappedSend(callAs("me", {channel: "lobby", text: "가".repeat(100)}))).resolves.toHaveProperty(
      "messageId",
    );
  });

  test("로그인하지 않으면 거절한다", async () => {
    const error = await expectHttpsError(() => wrappedSend(callAs(null, {channel: "lobby", text: "안녕"})));
    expect(error.code).toBe("unauthenticated");
  });
});

describe("reportMessage", () => {
  /** 로비에 [count]개의 메시지를 차례로 보내고 메시지 ID를 돌려준다. 짝수는 cho, 홀수는 han이 보낸다. */
  async function sendLobbyMessages(count: number): Promise<string[]> {
    const messageIds: string[] = [];
    for (let i = 0; i < count; i++) {
      const uid = i % 2 === 0 ? "cho" : "han";
      const result = (await wrappedSend(callAs(uid, {channel: "lobby", text: `메시지${i}`}))) as {messageId: string};
      messageIds.push(result.messageId);
    }
    return messageIds;
  }

  test("신고된 메시지와 앞뒤 다섯 개, 검사 결과 사본으로 신고를 만든다", async () => {
    const messageIds = await sendLobbyMessages(13);
    const target = messageIds[6];

    await expect(wrappedReport(callAs("me", {channel: "lobby", messageId: target}))).resolves.toEqual({});

    const report = (await db.doc(`reports/${target}_me`).get()).data();
    expect(report).toMatchObject({
      reporterUid: "me",
      targetUid: "cho",
      channel: "lobby",
      gameId: null,
      message: {messageId: target, uid: "cho", nickname: "초사람", text: "메시지6"},
      check: {scores: PASSED.scores, bannedWordMatched: false},
      status: "pending",
      resolution: null,
      resolvedAt: null,
      expiresAt: null,
    });
    expect((report?.context as {text: string}[]).map((message) => message.text)).toEqual([
      "메시지1",
      "메시지2",
      "메시지3",
      "메시지4",
      "메시지5",
      "메시지7",
      "메시지8",
      "메시지9",
      "메시지10",
      "메시지11",
    ]);
  });

  test("같은 메시지를 다시 신고하면 신고 하나만 남긴다", async () => {
    const [target] = await sendLobbyMessages(1);
    await wrappedReport(callAs("me", {channel: "lobby", messageId: target}));
    await wrappedReport(callAs("me", {channel: "lobby", messageId: target}));
    expect((await db.collection("reports").get()).size).toBe(1);
  });

  test("내 메시지와 없는 메시지는 신고하지 못한다", async () => {
    const [target] = await sendLobbyMessages(1);
    let error = await expectHttpsError(() => wrappedReport(callAs("cho", {channel: "lobby", messageId: target})));
    expect(error.details).toEqual({code: "notAllowed"});
    error = await expectHttpsError(() => wrappedReport(callAs("me", {channel: "lobby", messageId: "missing"})));
    expect(error.details).toEqual({code: "notFound"});
  });

  test("대국 채팅은 상대 대국자만 신고한다", async () => {
    await createGame("g1", "playing");
    const result = (await wrappedSend(callAs("cho", {channel: "game", gameId: "g1", text: "안녕하세요"}))) as {
      messageId: string;
    };
    let error = await expectHttpsError(() =>
      wrappedReport(callAs("me", {channel: "game", gameId: "g1", messageId: result.messageId})),
    );
    expect(error.details).toEqual({code: "notAllowed"});

    await wrappedReport(callAs("han", {channel: "game", gameId: "g1", messageId: result.messageId}));
    const report = (await db.doc(`reports/${result.messageId}_han`).get()).data();
    expect(report).toMatchObject({channel: "game", gameId: "g1", targetUid: "cho", context: []});

    error = await expectHttpsError(() =>
      wrappedReport(callAs("me", {channel: "game", gameId: "g1", messageId: "bad.id"})),
    );
    expect(error.code).toBe("invalid-argument");
  });
});

describe("cleanupChats", () => {
  test("90일이 지난 로비 메시지와 마지막 메시지가 90일 지난 대국 채팅을 지운다", async () => {
    const now = dayjs();
    const old = now.subtract(91, "day").valueOf();
    const recent = now.subtract(89, "day").valueOf();
    const message = (sentAt: number) => ({uid: "cho", nickname: "초사람", text: "안녕", sentAt});
    await rtdb.ref().update({
      "chats_lobby/a": message(old),
      "chats_lobby/b": message(old),
      "chats_lobby/c": message(recent),
      "chats_game/oldGame/a": message(old),
      "chats_game/newGame/a": message(old),
      "chats_game/newGame/b": message(recent),
      "chats_spectator/oldGame/a": message(old),
    });

    await expect(cleanupChats(now)).resolves.toEqual({lobbyMessages: 2, gameChats: 2});

    expect(Object.keys((await getValue("chats_lobby")) as object)).toEqual(["c"]);
    expect(Object.keys((await getValue("chats_game")) as object)).toEqual(["newGame"]);
    expect(await getValue("chats_spectator")).toBeNull();
  });
});
