import {ChatChannel} from "./chat";
import {ReportStatus} from "./report";
import {SanctionType} from "./userPrivate";

/**
 * Admin Callable이 거절한 이유. 오류의 `details.code`로 Admin 웹에 보낸다. Admin 웹의 `AdminErrorCode`
 * (server/admin/src/models/admin.ts)와 값을 일치시킨다.
 */
export const AdminErrorCode = {
  // 신고나 사용자가 없다.
  notFound: "notFound",
  // 이미 처리한 신고다. 두 관리자가 같은 신고를 처리하거나 응답을 못 받고 다시 누른 경우다.
  alreadyResolved: "alreadyResolved",
  // 탈퇴한 사용자가 아니다.
  notDeleted: "notDeleted",
} as const;
export type AdminErrorCode = (typeof AdminErrorCode)[keyof typeof AdminErrorCode];

/** 신고 처리 조치. 무혐의이거나 제재 종류다. */
export type ReportAction = "dismissed" | SanctionType;

/** 목록의 다음 쪽을 읽는 위치. 앞 쪽 마지막 항목의 정렬 시각(epoch ms)과 문서 ID다. */
export interface PageCursor {
  afterMs: number;
  afterId: string;
}

export interface Page<T> {
  items: T[];
  // 다음 쪽이 없으면 null.
  nextCursor: PageCursor | null;
}

// 아래는 Admin Callable 응답 모양이다. 시각은 모두 epoch ms다. Admin 웹의 같은 이름 타입과 일치시킨다.

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

/** 신고 목록의 한 줄. */
export interface ReportSummaryView {
  reportId: string;
  status: ReportStatus;
  channel: ChatChannel;
  reporterUid: string;
  // 지금 닉네임. 프로필이 없으면 null.
  reporterNickname: string | null;
  targetUid: string;
  targetNickname: string | null;
  messageText: string;
  createdAt: number;
  resolvedAt: number | null;
  action: ReportAction | null;
}

/** 신고 상세. */
export interface ReportDetailView extends ReportSummaryView {
  gameId: string | null;
  message: ReportMessageView;
  context: ReportMessageView[];
  check: {scores: Record<string, number>; bannedWordMatched: boolean} | null;
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
  // 지금 닉네임. 프로필이 없으면 null.
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

/** 사용자 조회와 신고 상세의 피신고자 정보. 최근 기록을 ADMIN_HISTORY_LIMIT개씩 담는다. */
export interface UserHistoryView {
  uid: string;
  // 공개 프로필(`users/{uid}`). 없으면 null.
  profile: {
    nickname: string;
    rankLevel: number;
    stats: {games: number; wins: number; losses: number};
    createdAt: number;
    // 회원 탈퇴를 누른 시각. 탈퇴하지 않았으면 null.
    deletedAt: number | null;
  } | null;
  // 지금 걸린 제재(`users_private.sanction`). 끝났지만 예약 작업이 아직 지우지 않은 제재도 그대로 담는다.
  sanction: ActiveSanctionView | null;
  sanctions: SanctionView[];
  // 이 사용자가 신고된 기록.
  reports: ReportSummaryView[];
  moderationLogs: ModerationLogView[];
  nicknameChanges: NicknameChangeView[];
}

export interface ReportWithTargetView {
  report: ReportDetailView;
  target: UserHistoryView;
}

/** 잔액이 [min] 이상 [max] 미만인 지갑 수. [max]가 null이면 위가 열려 있다. */
export interface CoinBalanceBucketView {
  min: number;
  max: number | null;
  count: number;
}

/** 하루(서울 기준)의 엽전 지표. rewardedAds는 그 기능이 생기면 쌓인다. */
export interface CoinDayStatsView {
  // yyyy-MM-dd.
  day: string;
  // 이날 끝난 대국 수. 시간 연장과 놓아보기 비율의 분모다.
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
