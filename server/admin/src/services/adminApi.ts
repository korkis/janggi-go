import {FirebaseError} from "firebase/app";
import {httpsCallable} from "firebase/functions";
import {
  ADMIN_ERROR_CODES,
  type ActiveSanctionView,
  type AdminErrorCode,
  type AppConfig,
  CHAT_CHANNELS,
  type CoinStatsView,
  type ModerationLogView,
  type Page,
  type PageCursor,
  REPORT_ACTIONS,
  REPORT_STATUSES,
  type ReportDetailView,
  type ReportMessageView,
  type ReportStatus,
  type ReportSummaryView,
  type ReportWithTargetView,
  type ResolveReportInput,
  SANCTION_TYPES,
  type SanctionInput,
  type SanctionView,
  type UserHistoryView,
} from "../models/admin";
import {functions} from "./firebase";
import {
  ParseError,
  asArray,
  asBoolean,
  asEnum,
  asNullable,
  asNumber,
  asNumberMap,
  asRecord,
  asString,
  asStringArray,
} from "./parse";

// Admin Callable 호출과 응답 검증의 경계다(docs/dev_rules.md의 Admin 웹 규칙). 화면과 store는 Firebase SDK 대신 이 함수를 쓴다.
// Functions가 모든 호출에서 admin claim을 다시 확인한다.

/** 화면이 구분해 보여주는 실패 종류. */
export type AdminApiErrorKind =
  // 로그인이 풀렸거나 관리자가 아니다.
  | "permission"
  // 신고나 사용자가 없다.
  | "notFound"
  // 이미 처리한 신고다.
  | "alreadyResolved"
  | "notDeleted"
  // 입력이 서버 검사를 통과하지 못했다.
  | "invalid"
  // 네트워크나 서버 문제. 다시 시도할 수 있다.
  | "retryable"
  // 응답 모양이 계약과 다르다.
  | "contract";

export class AdminApiError extends Error {
  readonly kind: AdminApiErrorKind;
  readonly callable: string;

  constructor(kind: AdminApiErrorKind, callable: string, message: string) {
    super(message);
    this.name = "AdminApiError";
    this.kind = kind;
    this.callable = callable;
  }
}

function getDetailsCode(details: unknown): AdminErrorCode | null {
  if (typeof details !== "object" || details === null) {
    return null;
  }
  const code = (details as Record<string, unknown>).code;
  return typeof code === "string" && (ADMIN_ERROR_CODES as readonly string[]).includes(code)
    ? (code as AdminErrorCode)
    : null;
}

function toAdminApiError(callable: string, error: unknown): AdminApiError {
  if (error instanceof ParseError) {
    return new AdminApiError("contract", callable, error.message);
  }
  if (!(error instanceof FirebaseError)) {
    return new AdminApiError("retryable", callable, "알 수 없는 오류");
  }
  const detailsCode = getDetailsCode((error as FirebaseError & {details?: unknown}).details);
  if (detailsCode === "notDeleted") {
    return new AdminApiError("notDeleted", callable, error.message);
  }
  if (detailsCode === "alreadyResolved") {
    return new AdminApiError("alreadyResolved", callable, error.message);
  }
  switch (error.code) {
    case "functions/unauthenticated":
    case "functions/permission-denied":
      return new AdminApiError("permission", callable, error.message);
    case "functions/not-found":
      return new AdminApiError("notFound", callable, error.message);
    case "functions/invalid-argument":
    case "functions/failed-precondition":
      return new AdminApiError("invalid", callable, error.message);
    default:
      return new AdminApiError("retryable", callable, error.message);
  }
}

/** [name] Callable을 부르고 응답을 [parse]로 검증한다. 실패는 AdminApiError로 바꾼다. payload와 응답은 로그에 남기지 않는다. */
async function call<T>(name: string, payload: unknown, parse: (data: unknown) => T): Promise<T> {
  try {
    const result = await httpsCallable(functions, name)(payload);
    return parse(result.data);
  } catch (error) {
    const adminError = toAdminApiError(name, error);
    console.error("Admin Callable 실패", {callable: name, kind: adminError.kind});
    throw adminError;
  }
}

// 응답 검증

function parseCursor(value: unknown, path: string): PageCursor {
  const record = asRecord(value, path);
  return {afterMs: asNumber(record.afterMs, `${path}.afterMs`), afterId: asString(record.afterId, `${path}.afterId`)};
}

function parsePage<T>(value: unknown, parseItem: (item: unknown, path: string) => T): Page<T> {
  const record = asRecord(value, "page");
  return {
    items: asArray(record.items, "page.items", parseItem),
    nextCursor: asNullable(record.nextCursor, "page.nextCursor", parseCursor),
  };
}

function parseMessage(value: unknown, path: string): ReportMessageView {
  const record = asRecord(value, path);
  return {
    messageId: asString(record.messageId, `${path}.messageId`),
    uid: asString(record.uid, `${path}.uid`),
    nickname: asString(record.nickname, `${path}.nickname`),
    text: asString(record.text, `${path}.text`),
    sentAt: asNumber(record.sentAt, `${path}.sentAt`),
  };
}

function parseReportSummary(value: unknown, path: string): ReportSummaryView {
  const record = asRecord(value, path);
  return {
    reportId: asString(record.reportId, `${path}.reportId`),
    status: asEnum(record.status, REPORT_STATUSES, `${path}.status`),
    channel: asEnum(record.channel, CHAT_CHANNELS, `${path}.channel`),
    reporterUid: asString(record.reporterUid, `${path}.reporterUid`),
    reporterNickname: asNullable(record.reporterNickname, `${path}.reporterNickname`, asString),
    targetUid: asString(record.targetUid, `${path}.targetUid`),
    targetNickname: asNullable(record.targetNickname, `${path}.targetNickname`, asString),
    messageText: asString(record.messageText, `${path}.messageText`),
    createdAt: asNumber(record.createdAt, `${path}.createdAt`),
    resolvedAt: asNullable(record.resolvedAt, `${path}.resolvedAt`, asNumber),
    action: asNullable(record.action, `${path}.action`, (item, itemPath) => asEnum(item, REPORT_ACTIONS, itemPath)),
  };
}

function parseReportDetail(value: unknown, path: string): ReportDetailView {
  const record = asRecord(value, path);
  return {
    ...parseReportSummary(value, path),
    gameId: asNullable(record.gameId, `${path}.gameId`, asString),
    message: parseMessage(record.message, `${path}.message`),
    context: asArray(record.context, `${path}.context`, parseMessage),
    check: asNullable(record.check, `${path}.check`, (item, itemPath) => {
      const check = asRecord(item, itemPath);
      return {
        scores: asNumberMap(check.scores, `${itemPath}.scores`),
        bannedWordMatched: asBoolean(check.bannedWordMatched, `${itemPath}.bannedWordMatched`),
      };
    }),
    resolution: asNullable(record.resolution, `${path}.resolution`, (item, itemPath) => {
      const resolution = asRecord(item, itemPath);
      return {
        action: asEnum(resolution.action, REPORT_ACTIONS, `${itemPath}.action`),
        reason: asString(resolution.reason, `${itemPath}.reason`),
        adminUid: asString(resolution.adminUid, `${itemPath}.adminUid`),
        sanctionId: asNullable(resolution.sanctionId, `${itemPath}.sanctionId`, asString),
      };
    }),
  };
}

function parseSanction(value: unknown, path: string): SanctionView {
  const record = asRecord(value, path);
  return {
    sanctionId: asString(record.sanctionId, `${path}.sanctionId`),
    type: asEnum(record.type, SANCTION_TYPES, `${path}.type`),
    startsAt: asNumber(record.startsAt, `${path}.startsAt`),
    endsAt: asNullable(record.endsAt, `${path}.endsAt`, asNumber),
    reason: asString(record.reason, `${path}.reason`),
    reportId: asNullable(record.reportId, `${path}.reportId`, asString),
    adminUid: asNullable(record.adminUid, `${path}.adminUid`, asString),
    createdAt: asNumber(record.createdAt, `${path}.createdAt`),
  };
}

function parseActiveSanction(value: unknown, path: string): ActiveSanctionView {
  const record = asRecord(value, path);
  return {
    type: asEnum(record.type, SANCTION_TYPES, `${path}.type`),
    endsAt: asNullable(record.endsAt, `${path}.endsAt`, asNumber),
    reason: asString(record.reason, `${path}.reason`),
  };
}

function parseModerationLog(value: unknown, path: string): ModerationLogView {
  const record = asRecord(value, path);
  return {
    logId: asString(record.logId, `${path}.logId`),
    uid: asString(record.uid, `${path}.uid`),
    nickname: asNullable(record.nickname, `${path}.nickname`, asString),
    channel: asEnum(record.channel, CHAT_CHANNELS, `${path}.channel`),
    gameId: asNullable(record.gameId, `${path}.gameId`, asString),
    text: asString(record.text, `${path}.text`),
    categories: asStringArray(record.categories, `${path}.categories`),
    scores: asNumberMap(record.scores, `${path}.scores`),
    bannedWordMatched: asBoolean(record.bannedWordMatched, `${path}.bannedWordMatched`),
    createdAt: asNumber(record.createdAt, `${path}.createdAt`),
  };
}

function parseUserHistory(value: unknown, path: string): UserHistoryView {
  const record = asRecord(value, path);
  return {
    uid: asString(record.uid, `${path}.uid`),
    profile: asNullable(record.profile, `${path}.profile`, (item, itemPath) => {
      const profile = asRecord(item, itemPath);
      const stats = asRecord(profile.stats, `${itemPath}.stats`);
      return {
        nickname: asString(profile.nickname, `${itemPath}.nickname`),
        rankLevel: asNumber(profile.rankLevel, `${itemPath}.rankLevel`),
        stats: {
          games: asNumber(stats.games, `${itemPath}.stats.games`),
          wins: asNumber(stats.wins, `${itemPath}.stats.wins`),
          losses: asNumber(stats.losses, `${itemPath}.stats.losses`),
        },
        createdAt: asNumber(profile.createdAt, `${itemPath}.createdAt`),
        deletedAt: asNullable(profile.deletedAt, `${itemPath}.deletedAt`, asNumber),
      };
    }),
    sanction: asNullable(record.sanction, `${path}.sanction`, parseActiveSanction),
    sanctions: asArray(record.sanctions, `${path}.sanctions`, parseSanction),
    reports: asArray(record.reports, `${path}.reports`, parseReportSummary),
    moderationLogs: asArray(record.moderationLogs, `${path}.moderationLogs`, parseModerationLog),
    nicknameChanges: asArray(record.nicknameChanges, `${path}.nicknameChanges`, (item, itemPath) => {
      const change = asRecord(item, itemPath);
      return {
        before: asString(change.before, `${itemPath}.before`),
        after: asString(change.after, `${itemPath}.after`),
        changedAt: asNumber(change.changedAt, `${itemPath}.changedAt`),
      };
    }),
  };
}

function parseReportWithTarget(value: unknown): ReportWithTargetView {
  const record = asRecord(value, "result");
  return {
    report: parseReportDetail(record.report, "result.report"),
    target: parseUserHistory(record.target, "result.target"),
  };
}

function parseAppConfig(value: unknown): AppConfig {
  const record = asRecord(value, "config");
  return {
    disconnectLimitSeconds: asNumber(record.disconnectLimitSeconds, "config.disconnectLimitSeconds"),
    quickRematchLimit: asNumber(record.quickRematchLimit, "config.quickRematchLimit"),
    onlineUsersVisible: asBoolean(record.onlineUsersVisible, "config.onlineUsersVisible"),
    autoSanctionEnabled: asBoolean(record.autoSanctionEnabled, "config.autoSanctionEnabled"),
    heartbeatSeconds: asNumber(record.heartbeatSeconds, "config.heartbeatSeconds"),
    entryFeeEnabled: asBoolean(record.entryFeeEnabled, "config.entryFeeEnabled"),
    coinSignupBonus: asNumber(record.coinSignupBonus, "config.coinSignupBonus"),
    coinEntryFee: asNumber(record.coinEntryFee, "config.coinEntryFee"),
    coinWinReward: asNumber(record.coinWinReward, "config.coinWinReward"),
    coinLossReward: asNumber(record.coinLossReward, "config.coinLossReward"),
    coinAttendanceReward: asNumber(record.coinAttendanceReward, "config.coinAttendanceReward"),
    coinAttendanceStreakReward: asNumber(record.coinAttendanceStreakReward, "config.coinAttendanceStreakReward"),
    coinNicknameChangeCost: asNumber(record.coinNicknameChangeCost, "config.coinNicknameChangeCost"),
    timeExtensionEnabled: asBoolean(record.timeExtensionEnabled, "config.timeExtensionEnabled"),
    gamePracticeEnabled: asBoolean(record.gamePracticeEnabled, "config.gamePracticeEnabled"),
    coinTimeExtensionCost: asNumber(record.coinTimeExtensionCost, "config.coinTimeExtensionCost"),
    coinGamePracticeCost: asNumber(record.coinGamePracticeCost, "config.coinGamePracticeCost"),
    chatEnabled: asBoolean(record.chatEnabled, "config.chatEnabled"),
    signupEnabled: asBoolean(record.signupEnabled, "config.signupEnabled"),
    webEnabled: asBoolean(record.webEnabled, "config.webEnabled"),
    coinSaleEnabled: asBoolean(record.coinSaleEnabled, "config.coinSaleEnabled"),
    minAppVersion: asString(record.minAppVersion, "config.minAppVersion"),
    serviceNotice: asNullable(record.serviceNotice, "config.serviceNotice", (item, itemPath) => {
      const notice = asRecord(item, itemPath);
      return {
        messageKo: asString(notice.messageKo, `${itemPath}.messageKo`),
        messageEn: asString(notice.messageEn, `${itemPath}.messageEn`),
        gamesBlocked: asBoolean(notice.gamesBlocked, `${itemPath}.gamesBlocked`),
      };
    }),
  };
}

function parseCoinStats(value: unknown): CoinStatsView {
  const record = asRecord(value, "stats");
  return {
    balanceBuckets: asArray(record.balanceBuckets, "stats.balanceBuckets", (item, itemPath) => {
      const bucket = asRecord(item, itemPath);
      return {
        min: asNumber(bucket.min, `${itemPath}.min`),
        max: asNullable(bucket.max, `${itemPath}.max`, asNumber),
        count: asNumber(bucket.count, `${itemPath}.count`),
      };
    }),
    days: asArray(record.days, "stats.days", (item, itemPath) => {
      const day = asRecord(item, itemPath);
      return {
        day: asString(day.day, `${itemPath}.day`),
        games: asNumber(day.games, `${itemPath}.games`),
        timeExtensions: asNumber(day.timeExtensions, `${itemPath}.timeExtensions`),
        gamePractices: asNumber(day.gamePractices, `${itemPath}.gamePractices`),
        rewardedAds: asNumber(day.rewardedAds, `${itemPath}.rewardedAds`),
      };
    }),
  };
}

// Callable

export function getReports(status: ReportStatus, cursor: PageCursor | null): Promise<Page<ReportSummaryView>> {
  return call("adminGetReports", {status, cursor}, (data) => parsePage(data, parseReportSummary));
}

export function getReport(reportId: string): Promise<ReportWithTargetView> {
  return call("adminGetReport", {reportId}, parseReportWithTarget);
}

export function resolveReport(reportId: string, input: ResolveReportInput): Promise<ReportWithTargetView> {
  return call("adminResolveReport", {reportId, ...input}, parseReportWithTarget);
}

export function getModerationLogs(uid: string | null, cursor: PageCursor | null): Promise<Page<ModerationLogView>> {
  return call("adminGetModerationLogs", {uid, cursor}, (data) => parsePage(data, parseModerationLog));
}

export function getUser(uid: string): Promise<UserHistoryView> {
  return call("adminGetUser", {uid}, (data) => parseUserHistory(data, "user"));
}

export function findUserByNickname(nickname: string): Promise<UserHistoryView> {
  return call("adminGetUser", {nickname}, (data) => parseUserHistory(data, "user"));
}

export function sanctionUser(uid: string, input: SanctionInput): Promise<UserHistoryView> {
  return call("adminSanctionUser", {uid, ...input}, (data) => parseUserHistory(data, "user"));
}

export function restoreAccount(uid: string, reason: string): Promise<UserHistoryView> {
  return call("adminRestoreAccount", {uid, reason}, (data) => parseUserHistory(data, "user"));
}

export function getAppConfig(): Promise<AppConfig> {
  return call("adminGetAppConfig", null, parseAppConfig);
}

export function updateAppConfig(config: AppConfig): Promise<AppConfig> {
  return call("adminUpdateAppConfig", {config}, parseAppConfig);
}

export function getCoinStats(): Promise<CoinStatsView> {
  return call("adminGetCoinStats", null, parseCoinStats);
}
