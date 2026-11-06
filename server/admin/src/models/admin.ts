// Admin Callable의 요청·응답 모양이다. Functions의 같은 이름 타입(server/functions/src/models/admin.ts 등)과 일치시킨다.
// 시각은 모두 epoch ms다.

/** 제재 종류. 앱, Functions, 대국 서버와 값을 일치시킨다(docs/database.md의 공통 enum). */
export const SANCTION_TYPES = ["warning", "chatRestriction", "suspension", "permanentBan"] as const;
export type SanctionType = (typeof SANCTION_TYPES)[number];

export const REPORT_STATUSES = ["pending", "resolved"] as const;
export type ReportStatus = (typeof REPORT_STATUSES)[number];

export const CHAT_CHANNELS = ["lobby", "game", "spectator"] as const;
export type ChatChannel = (typeof CHAT_CHANNELS)[number];

/** 신고 처리 조치. 무혐의이거나 제재 종류다. */
export const REPORT_ACTIONS = ["dismissed", ...SANCTION_TYPES] as const;
export type ReportAction = (typeof REPORT_ACTIONS)[number];

/** Admin Callable이 `details.code`로 보내는 거절 이유. */
export const ADMIN_ERROR_CODES = ["notFound", "alreadyResolved"] as const;
export type AdminErrorCode = (typeof ADMIN_ERROR_CODES)[number];

/** Firebase Auth ID token의 custom claim 중 Admin 웹이 보는 것. */
export interface AdminClaims {
  admin: boolean;
}

/** 목록의 다음 쪽을 읽는 위치. */
export interface PageCursor {
  afterMs: number;
  afterId: string;
}

export interface Page<T> {
  items: T[];
  nextCursor: PageCursor | null;
}

export interface ReportMessageView {
  messageId: string;
  uid: string;
  nickname: string;
  text: string;
  sentAt: number;
}

export interface ReportResolutionView {
  action: ReportAction;
  reason: string;
  adminUid: string;
  sanctionId: string | null;
}

export interface ReportSummaryView {
  reportId: string;
  status: ReportStatus;
  channel: ChatChannel;
  reporterUid: string;
  reporterNickname: string | null;
  targetUid: string;
  targetNickname: string | null;
  messageText: string;
  createdAt: number;
  resolvedAt: number | null;
  action: ReportAction | null;
}

export interface ModerationCheckView {
  scores: Record<string, number>;
  bannedWordMatched: boolean;
}

export interface ReportDetailView extends ReportSummaryView {
  gameId: string | null;
  message: ReportMessageView;
  context: ReportMessageView[];
  check: ModerationCheckView | null;
  resolution: ReportResolutionView | null;
}

export interface SanctionView {
  sanctionId: string;
  type: SanctionType;
  startsAt: number;
  endsAt: number | null;
  reason: string;
  reportId: string | null;
  adminUid: string | null;
  createdAt: number;
}

export interface ActiveSanctionView {
  type: SanctionType;
  endsAt: number | null;
  reason: string;
}

export interface ModerationLogView {
  logId: string;
  uid: string;
  nickname: string | null;
  channel: ChatChannel;
  gameId: string | null;
  text: string;
  categories: string[];
  scores: Record<string, number>;
  bannedWordMatched: boolean;
  createdAt: number;
}

export interface NicknameChangeView {
  before: string;
  after: string;
  changedAt: number;
}

export interface UserProfileView {
  nickname: string;
  rankLevel: number;
  stats: {games: number; wins: number; losses: number};
  createdAt: number;
}

export interface UserHistoryView {
  uid: string;
  profile: UserProfileView | null;
  sanction: ActiveSanctionView | null;
  sanctions: SanctionView[];
  reports: ReportSummaryView[];
  moderationLogs: ModerationLogView[];
  nicknameChanges: NicknameChangeView[];
}

export interface ReportWithTargetView {
  report: ReportDetailView;
  target: UserHistoryView;
}

/** Firestore `configs/app`. 필드 설명은 docs/server.md의 "configs/app". */
export interface AppConfig {
  disconnectLimitSeconds: number;
  quickRematchLimit: number;
  onlineUsersVisible: boolean;
  autoSanctionEnabled: boolean;
  heartbeatSeconds: number;
  entryFeeEnabled: boolean;
  coinSignupBonus: number;
  coinEntryFee: number;
  coinWinReward: number;
  coinDrawReward: number;
  coinLossReward: number;
  coinAttendanceReward: number;
  coinAttendanceStreakReward: number;
  coinRescueReward: number;
  coinRescueThreshold: number;
  coinNicknameChangeCost: number;
}

/** 잔액이 [min] 이상 [max] 미만인 지갑 수. [max]가 null이면 위가 열려 있다. */
export interface CoinBalanceBucketView {
  min: number;
  max: number | null;
  count: number;
}

/** 하루(서울 기준)의 엽전 지표. */
export interface CoinDayStatsView {
  day: string;
  games: number;
  timeExtensions: number;
  gamePractices: number;
  rewardedAds: number;
}

export interface CoinStatsView {
  balanceBuckets: CoinBalanceBucketView[];
  // 최근 날부터.
  days: CoinDayStatsView[];
}

/** 걸 제재. 채팅 제한과 이용 정지는 기간이 있고, 경고와 영구 정지는 null이다. */
export interface SanctionInput {
  type: SanctionType;
  durationDays: number | null;
  reason: string;
}

/** 신고 처리 입력. */
export interface ResolveReportInput {
  action: ReportAction;
  durationDays: number | null;
  reason: string;
}
