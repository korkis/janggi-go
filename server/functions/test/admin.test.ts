import dayjs from "dayjs";
import {deleteApp, getApp, initializeApp} from "firebase-admin/app";
import {Timestamp, getFirestore} from "firebase-admin/firestore";
import functionsTest from "firebase-functions-test";
import {HttpsError} from "firebase-functions/https";
import {adminGetAppConfig} from "../src/callables/adminGetAppConfig";
import {adminGetModerationLogs} from "../src/callables/adminGetModerationLogs";
import {adminGetReport} from "../src/callables/adminGetReport";
import {adminGetReports} from "../src/callables/adminGetReports";
import {adminGetUser} from "../src/callables/adminGetUser";
import {adminResolveReport} from "../src/callables/adminResolveReport";
import {adminSanctionUser} from "../src/callables/adminSanctionUser";
import {adminUpdateAppConfig} from "../src/callables/adminUpdateAppConfig";
import {ADMIN_PAGE_SIZE} from "../src/config";
import {ModerationLogView, Page, ReportSummaryView, ReportWithTargetView, UserHistoryView} from "../src/models/admin";
import {INITIAL_APP_CONFIG} from "../src/models/appConfig";
import {expireSanctions} from "../src/services/sanctionService";
import {TEST_PROJECT_ID} from "./testEnv";

const fft = functionsTest({projectId: TEST_PROJECT_ID});
initializeApp({projectId: TEST_PROJECT_ID});
const db = getFirestore();

const wrappedGetReports = fft.wrap(adminGetReports);
const wrappedGetReport = fft.wrap(adminGetReport);
const wrappedResolveReport = fft.wrap(adminResolveReport);
const wrappedGetModerationLogs = fft.wrap(adminGetModerationLogs);
const wrappedGetUser = fft.wrap(adminGetUser);
const wrappedSanctionUser = fft.wrap(adminSanctionUser);
const wrappedGetAppConfig = fft.wrap(adminGetAppConfig);
const wrappedUpdateAppConfig = fft.wrap(adminUpdateAppConfig);

const ADMIN = "admin1";

const APP_CONFIG = INITIAL_APP_CONFIG;

// fft.wrap은 CallableRequest 전체를 받는다. 테스트에 필요한 필드만 채운다. [admin]이면 ID token에 admin claim을 넣는다.
function callAs(uid: string | null, data: unknown, admin = false) {
  return {
    data,
    auth: uid === null ? undefined : {uid, token: admin ? {uid, admin: true} : {uid}},
    rawRequest: {},
    acceptsStreaming: false,
  } as never;
}

function callAsAdmin(data: unknown) {
  return callAs(ADMIN, data, true);
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
  await db.doc(`users/${uid}`).set({
    nickname,
    rankLevel: 3,
    stats: {games: 2, wins: 1, losses: 1},
    createdAt: Timestamp.now(),
  });
  await db.doc(`users_private/${uid}`).set({challengesEnabled: true, sanction});
  await db.doc(`nicknames/${nickname.toLowerCase()}`).set({uid, createdAt: Timestamp.now()});
}

function message(messageId: string, uid: string, nickname: string, text: string, sentAt: number) {
  return {messageId, uid, nickname, text, sentAt};
}

/** [reporterUid]가 [targetUid]의 [messageId] 메시지를 신고한 기록을 만든다. */
async function createReport(
  messageId: string,
  reporterUid: string,
  targetUid: string,
  createdAt: dayjs.Dayjs,
): Promise<string> {
  const reportId = `${messageId}_${reporterUid}`;
  await db.doc(`reports/${reportId}`).set({
    reporterUid,
    targetUid,
    channel: "lobby",
    gameId: null,
    message: message(messageId, targetUid, "나쁜사람", "바보야", createdAt.valueOf()),
    context: [
      message("m0", reporterUid, "신고자", "안녕하세요", createdAt.valueOf() - 1000),
      message("m2", reporterUid, "신고자", "왜 그래요", createdAt.valueOf() + 1000),
    ],
    check: {scores: {harassment: 0.4}, bannedWordMatched: false},
    status: "pending",
    resolution: null,
    createdAt: Timestamp.fromDate(createdAt.toDate()),
    resolvedAt: null,
    expiresAt: null,
  });
  return reportId;
}

async function getData(path: string): Promise<FirebaseFirestore.DocumentData | undefined> {
  return (await db.doc(path).get()).data();
}

beforeEach(async () => {
  await clearFirestore();
  await createUser("reporter", "신고자");
  await createUser("reporter2", "신고자둘");
  await createUser("target", "BadGuy");
  await db.doc("configs/app").set(APP_CONFIG);
});

afterAll(async () => {
  fft.cleanup();
  await deleteApp(getApp());
});

describe("관리자 확인", () => {
  const calls: [string, (request: never) => unknown, unknown][] = [
    ["adminGetReports", wrappedGetReports, {status: "pending"}],
    ["adminGetReport", wrappedGetReport, {reportId: "m1_reporter"}],
    ["adminResolveReport", wrappedResolveReport, {reportId: "m1_reporter", action: "dismissed", reason: "문제 없음"}],
    ["adminGetModerationLogs", wrappedGetModerationLogs, {}],
    ["adminGetUser", wrappedGetUser, {uid: "target"}],
    ["adminSanctionUser", wrappedSanctionUser, {uid: "target", type: "warning", reason: "경고"}],
    ["adminGetAppConfig", wrappedGetAppConfig, {}],
    ["adminUpdateAppConfig", wrappedUpdateAppConfig, {config: APP_CONFIG}],
  ];

  test.each(calls)(
    "%s: 로그인하지 않았으면 unauthenticated, admin claim이 없으면 permission-denied",
    async (_, call, data) => {
      await createReport("m1", "reporter", "target", dayjs());
      expect((await expectHttpsError(() => call(callAs(null, data)))).code).toBe("unauthenticated");
      expect((await expectHttpsError(() => call(callAs("reporter", data)))).code).toBe("permission-denied");
      // claim이 true가 아니면 관리자가 아니다.
      const notTrue = {data, auth: {uid: "reporter", token: {uid: "reporter", admin: "true"}}, rawRequest: {}} as never;
      expect((await expectHttpsError(() => call(notTrue))).code).toBe("permission-denied");
      // 일반 사용자의 요청은 아무것도 바꾸지 않는다.
      expect((await getData("reports/m1_reporter"))?.status).toBe("pending");
      expect((await getData("users_private/target"))?.sanction).toBeNull();
      expect(await getData("configs/app")).toEqual(APP_CONFIG);
    },
  );
});

describe("신고 목록과 상세", () => {
  test("처리 전 신고는 오래된 것부터 한 쪽씩 읽는다", async () => {
    const start = dayjs().subtract(1, "hour");
    for (let i = 0; i < ADMIN_PAGE_SIZE + 1; i++) {
      await createReport(`m${String(i).padStart(2, "0")}`, "reporter", "target", start.add(i, "second"));
    }

    const first = (await wrappedGetReports(callAsAdmin({status: "pending"}))) as Page<ReportSummaryView>;
    expect(first.items).toHaveLength(ADMIN_PAGE_SIZE);
    expect(first.items[0]).toMatchObject({
      reportId: "m00_reporter",
      status: "pending",
      reporterNickname: "신고자",
      targetUid: "target",
      targetNickname: "BadGuy",
      messageText: "바보야",
      action: null,
      resolvedAt: null,
    });
    expect(first.nextCursor).toEqual({
      afterMs: start.add(ADMIN_PAGE_SIZE - 1, "second").valueOf(),
      afterId: "m19_reporter",
    });

    const second = (await wrappedGetReports(
      callAsAdmin({status: "pending", cursor: first.nextCursor}),
    )) as Page<ReportSummaryView>;
    expect(second.items.map((item) => item.reportId)).toEqual(["m20_reporter"]);
    expect(second.nextCursor).toBeNull();

    const resolved = (await wrappedGetReports(callAsAdmin({status: "resolved"}))) as Page<ReportSummaryView>;
    expect(resolved.items).toEqual([]);
  });

  test("상세는 신고된 메시지, 앞뒤 대화, 검사 결과, 피신고자의 지난 기록을 함께 준다", async () => {
    const reportId = await createReport("m1", "reporter", "target", dayjs());
    await db.collection("moderation_logs").add({
      uid: "target",
      channel: "lobby",
      gameId: null,
      text: "씨발",
      categories: [],
      scores: {},
      bannedWordMatched: true,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.now(),
    });
    await db.collection("nickname_changes").add({
      uid: "target",
      before: "OldGuy",
      after: "BadGuy",
      changedAt: Timestamp.now(),
    });

    const result = (await wrappedGetReport(callAsAdmin({reportId}))) as ReportWithTargetView;

    expect(result.report).toMatchObject({
      reportId,
      reporterNickname: "신고자",
      targetNickname: "BadGuy",
      message: {messageId: "m1", text: "바보야"},
      check: {scores: {harassment: 0.4}, bannedWordMatched: false},
      resolution: null,
    });
    expect(result.report.context.map((item) => item.text)).toEqual(["안녕하세요", "왜 그래요"]);
    expect(result.target.profile).toMatchObject({nickname: "BadGuy", rankLevel: 3});
    expect(result.target.reports.map((item) => item.reportId)).toEqual([reportId]);
    expect(result.target.moderationLogs).toEqual([
      expect.objectContaining({uid: "target", nickname: "BadGuy", text: "씨발", bannedWordMatched: true}),
    ]);
    expect(result.target.nicknameChanges).toEqual([expect.objectContaining({before: "OldGuy", after: "BadGuy"})]);
    expect(result.target.sanctions).toEqual([]);

    const error = await expectHttpsError(() => wrappedGetReport(callAsAdmin({reportId: "none"})));
    expect(error.code).toBe("not-found");
    expect(error.details).toEqual({code: "notFound"});
  });
});

describe("신고 처리", () => {
  test("채팅 제한 7일: 제재 이력과 지금 제재를 쓰고 같은 메시지의 신고를 함께 닫는다", async () => {
    const reportId = await createReport("m1", "reporter", "target", dayjs());
    await createReport("m1", "reporter2", "target", dayjs());
    await createReport("m9", "reporter", "target", dayjs());
    const before = dayjs();

    const result = (await wrappedResolveReport(
      callAsAdmin({reportId, action: "chatRestriction", durationDays: 7, reason: "  욕설  "}),
    )) as ReportWithTargetView;

    expect(result.report.status).toBe("resolved");
    expect(result.report.resolution).toMatchObject({action: "chatRestriction", reason: "욕설", adminUid: ADMIN});
    const sanctionId = result.report.resolution!.sanctionId!;
    const sanction = await getData(`sanctions/${sanctionId}`);
    expect(sanction).toMatchObject({uid: "target", type: "chatRestriction", reason: "욕설", reportId, adminUid: ADMIN});
    const endsAt = (sanction!.endsAt as Timestamp).toMillis();
    expect(endsAt - (sanction!.startsAt as Timestamp).toMillis()).toBe(7 * 24 * 60 * 60 * 1000);
    expect(endsAt).toBeGreaterThanOrEqual(before.add(7, "day").valueOf());

    const userPrivate = await getData("users_private/target");
    expect(userPrivate?.sanction).toEqual({
      type: "chatRestriction",
      endsAt: sanction!.endsAt as Timestamp,
      reason: "욕설",
    });
    expect(result.target.sanction).toEqual({type: "chatRestriction", endsAt, reason: "욕설"});
    expect(result.target.sanctions.map((item) => item.sanctionId)).toEqual([sanctionId]);

    const other = await getData("reports/m1_reporter2");
    expect(other).toMatchObject({status: "resolved", resolution: {action: "chatRestriction", sanctionId}});
    // 처리한 신고는 1년 뒤 지운다.
    const expiresAt = dayjs((other!.expiresAt as Timestamp).toDate());
    expect(expiresAt.diff(dayjs(), "day")).toBeGreaterThanOrEqual(364);
    // 다른 메시지의 신고는 그대로다.
    expect((await getData("reports/m9_reporter"))?.status).toBe("pending");
  });

  test("이미 처리한 신고는 alreadyResolved로 거절해 제재를 두 번 걸지 않는다", async () => {
    const reportId = await createReport("m1", "reporter", "target", dayjs());
    await wrappedResolveReport(callAsAdmin({reportId, action: "suspension", durationDays: 1, reason: "욕설"}));

    const error = await expectHttpsError(() =>
      wrappedResolveReport(callAsAdmin({reportId, action: "suspension", durationDays: 1, reason: "욕설"})),
    );
    expect(error.code).toBe("failed-precondition");
    expect(error.details).toEqual({code: "alreadyResolved"});
    expect((await db.collection("sanctions").get()).size).toBe(1);
  });

  test("무혐의는 제재 없이 닫는다", async () => {
    const reportId = await createReport("m1", "reporter", "target", dayjs());

    const result = (await wrappedResolveReport(
      callAsAdmin({reportId, action: "dismissed", reason: "문제 없는 표현"}),
    )) as ReportWithTargetView;

    expect(result.report.resolution).toEqual({
      action: "dismissed",
      reason: "문제 없는 표현",
      adminUid: ADMIN,
      sanctionId: null,
    });
    expect((await db.collection("sanctions").get()).size).toBe(0);
    expect((await getData("users_private/target"))?.sanction).toBeNull();
    const resolved = (await wrappedGetReports(callAsAdmin({status: "resolved"}))) as Page<ReportSummaryView>;
    expect(resolved.items.map((item) => [item.reportId, item.action])).toEqual([[reportId, "dismissed"]]);
  });

  test("경고는 아직 막고 있는 제재를 풀지 않고 이력에만 남긴다", async () => {
    const endsAt = Timestamp.fromDate(dayjs().add(3, "day").toDate());
    await db.doc("users_private/target").update({sanction: {type: "suspension", endsAt, reason: "앞선 정지"}});
    const reportId = await createReport("m1", "reporter", "target", dayjs());

    await wrappedResolveReport(callAsAdmin({reportId, action: "warning", reason: "경고"}));

    expect((await getData("users_private/target"))?.sanction).toEqual({
      type: "suspension",
      endsAt,
      reason: "앞선 정지",
    });
    const sanctions = await db.collection("sanctions").get();
    expect(sanctions.docs.map((doc) => [doc.get("type") as string, doc.get("endsAt") as null])).toEqual([
      ["warning", null],
    ]);
  });

  test("끝난 제재 뒤의 경고는 지금 제재가 된다", async () => {
    const endsAt = Timestamp.fromDate(dayjs().subtract(1, "minute").toDate());
    await db.doc("users_private/target").update({sanction: {type: "chatRestriction", endsAt, reason: "끝남"}});

    await wrappedSanctionUser(callAsAdmin({uid: "target", type: "warning", reason: "경고"}));

    expect((await getData("users_private/target"))?.sanction).toEqual({type: "warning", endsAt: null, reason: "경고"});
  });

  test.each([
    [{action: "chatRestriction", reason: "욕설"}, "durationDays"],
    [{action: "suspension", durationDays: 3, reason: "욕설"}, "durationDays"],
    [{action: "warning", durationDays: 1, reason: "욕설"}, "durationDays"],
    [{action: "permanentBan", durationDays: 30, reason: "욕설"}, "durationDays"],
    [{action: "dismissed", durationDays: 1, reason: "욕설"}, "durationDays"],
    [{action: "ban", reason: "욕설"}, "type"],
    [{action: "warning", reason: "   "}, "reason"],
    [{action: "warning", reason: "가".repeat(201)}, "reason"],
    [{action: "warning"}, "reason"],
  ])("잘못된 조치 %j는 invalid-argument", async (params, field) => {
    const reportId = await createReport("m1", "reporter", "target", dayjs());
    const error = await expectHttpsError(() => wrappedResolveReport(callAsAdmin({reportId, ...params})));
    expect(error.code).toBe("invalid-argument");
    expect(error.message).toContain(field);
    expect((await getData(`reports/${reportId}`))?.status).toBe("pending");
  });
});

describe("사용자 조회와 제재", () => {
  test("닉네임(대소문자 무시)이나 uid로 찾는다", async () => {
    const byNickname = (await wrappedGetUser(callAsAdmin({nickname: "badguy"}))) as UserHistoryView;
    expect(byNickname.uid).toBe("target");
    const byUid = (await wrappedGetUser(callAsAdmin({uid: "target"}))) as UserHistoryView;
    expect(byUid.profile?.nickname).toBe("BadGuy");

    expect((await expectHttpsError(() => wrappedGetUser(callAsAdmin({nickname: "없는사람"})))).details).toEqual({
      code: "notFound",
    });
    expect((await expectHttpsError(() => wrappedGetUser(callAsAdmin({uid: "none"})))).details).toEqual({
      code: "notFound",
    });
    expect((await expectHttpsError(() => wrappedGetUser(callAsAdmin({uid: "target", nickname: "BadGuy"})))).code).toBe(
      "invalid-argument",
    );
  });

  test("신고 없이 영구 정지를 건다", async () => {
    const result = (await wrappedSanctionUser(
      callAsAdmin({uid: "target", type: "permanentBan", reason: "반복된 욕설"}),
    )) as UserHistoryView;

    expect(result.sanction).toEqual({type: "permanentBan", endsAt: null, reason: "반복된 욕설"});
    expect(result.sanctions).toEqual([
      expect.objectContaining({type: "permanentBan", endsAt: null, reportId: null, adminUid: ADMIN}),
    ]);
    expect(
      (await expectHttpsError(() => wrappedSanctionUser(callAsAdmin({uid: "none", type: "warning", reason: "경고"}))))
        .details,
    ).toEqual({
      code: "notFound",
    });
  });
});

describe("검사 기록", () => {
  test("최근 것부터 읽고 사람별로 거른다", async () => {
    const now = dayjs();
    const log = (uid: string, text: string, minutesAgo: number) => ({
      uid,
      channel: "game",
      gameId: "g1",
      text,
      categories: ["harassment"],
      scores: {harassment: 0.9},
      bannedWordMatched: false,
      createdAt: Timestamp.fromDate(now.subtract(minutesAgo, "minute").toDate()),
      expiresAt: Timestamp.fromDate(now.add(1, "year").toDate()),
    });
    await db.collection("moderation_logs").add(log("target", "옛 메시지", 10));
    await db.collection("moderation_logs").add(log("target", "새 메시지", 1));
    await db.collection("moderation_logs").add(log("reporter", "다른 사람", 5));

    const all = (await wrappedGetModerationLogs(callAsAdmin({}))) as Page<ModerationLogView>;
    expect(all.items.map((item) => item.text)).toEqual(["새 메시지", "다른 사람", "옛 메시지"]);
    expect(all.items[0]).toMatchObject({nickname: "BadGuy", categories: ["harassment"], scores: {harassment: 0.9}});
    expect(all.nextCursor).toBeNull();

    const mine = (await wrappedGetModerationLogs(callAsAdmin({uid: "target"}))) as Page<ModerationLogView>;
    expect(mine.items.map((item) => item.text)).toEqual(["새 메시지", "옛 메시지"]);

    expect((await expectHttpsError(() => wrappedGetModerationLogs(callAsAdmin({cursor: {afterMs: "x"}})))).code).toBe(
      "invalid-argument",
    );
  });
});

describe("configs/app", () => {
  test("지금 값을 읽고 바꾼다", async () => {
    expect(await wrappedGetAppConfig(callAsAdmin({}))).toEqual(APP_CONFIG);
    const changed = {
      ...APP_CONFIG,
      onlineUsersVisible: true,
      disconnectLimitSeconds: 60,
      entryFeeEnabled: false,
      coinEntryFee: 20,
    };

    expect(await wrappedUpdateAppConfig(callAsAdmin({config: changed}))).toEqual(changed);

    expect(await getData("configs/app")).toEqual(changed);
  });

  test.each([
    {...APP_CONFIG, heartbeatSeconds: 6},
    {...APP_CONFIG, disconnectLimitSeconds: 9},
    {...APP_CONFIG, quickRematchLimit: 1.5},
    {...APP_CONFIG, onlineUsersVisible: "true"},
    {...APP_CONFIG, entryFeeEnabled: 1},
    {...APP_CONFIG, coinEntryFee: 101},
    {...APP_CONFIG, coinEntryFee: -1},
    {...APP_CONFIG, coinWinReward: 101},
    {...APP_CONFIG, coinSignupBonus: 3001},
    {...APP_CONFIG, coinAttendanceStreakReward: 1.5},
    {...APP_CONFIG, coinAttendanceReward: "30"},
    {...APP_CONFIG, coinNicknameChangeCost: 0},
    {...APP_CONFIG, coinTimeExtensionCost: 0},
    {...APP_CONFIG, coinTimeExtensionCost: 301},
    {...APP_CONFIG, coinGamePracticeCost: 0},
    {...APP_CONFIG, timeExtensionEnabled: 1},
    {...APP_CONFIG, gamePracticeEnabled: "true"},
    {...APP_CONFIG, chatEnabled: 1},
    {...APP_CONFIG, signupEnabled: "false"},
    {...APP_CONFIG, webEnabled: null},
    {...APP_CONFIG, coinSaleEnabled: "false"},
    {...APP_CONFIG, minAppVersion: "1.0"},
    {...APP_CONFIG, minAppVersion: 1},
    {...APP_CONFIG, serviceNotice: "점검"},
    {...APP_CONFIG, serviceNotice: {messageKo: "점검", messageEn: "Maintenance"}},
    {...APP_CONFIG, serviceNotice: {messageKo: "", messageEn: "Maintenance", gamesBlocked: false}},
    {...APP_CONFIG, serviceNotice: {messageKo: "점", messageEn: "x".repeat(201), gamesBlocked: false}},
    {...APP_CONFIG, serviceNotice: {messageKo: "점검", messageEn: "Maintenance", gamesBlocked: 1}},
    {...APP_CONFIG, serviceNotice: {messageKo: "점검", messageEn: "Maintenance", gamesBlocked: true, extra: 1}},
    {...APP_CONFIG, extra: 1},
    {disconnectLimitSeconds: 30},
  ])("범위를 벗어나거나 필드가 맞지 않으면 invalid-argument: %j", async (config) => {
    const error = await expectHttpsError(() => wrappedUpdateAppConfig(callAsAdmin({config})));
    expect(error.code).toBe("invalid-argument");
    expect(await getData("configs/app")).toEqual(APP_CONFIG);
  });
});

describe("expireSanctions", () => {
  test("끝난 채팅 제한과 이용 정지만 지운다", async () => {
    const past = Timestamp.fromDate(dayjs().subtract(1, "minute").toDate());
    const future = Timestamp.fromDate(dayjs().add(1, "day").toDate());
    await createUser("ended", "끝난사람", {type: "chatRestriction", endsAt: past, reason: "욕설"});
    await createUser("active", "정지중", {type: "suspension", endsAt: future, reason: "욕설"});
    await createUser("banned", "영구정지", {type: "permanentBan", endsAt: null, reason: "욕설"});
    await createUser("warned", "경고받음", {type: "warning", endsAt: null, reason: "욕설"});

    await expireSanctions();

    expect((await getData("users_private/ended"))?.sanction).toBeNull();
    expect((await getData("users_private/active"))?.sanction).toMatchObject({type: "suspension"});
    expect((await getData("users_private/banned"))?.sanction).toMatchObject({type: "permanentBan"});
    expect((await getData("users_private/warned"))?.sanction).toMatchObject({type: "warning"});
  });
});
