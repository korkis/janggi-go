import type {ChatChannel, ReportAction, ReportStatus, SanctionType} from "../models/admin";

// 화면에 보이는 글자로 바꾼다. 상태는 색만으로 구분하지 않도록 기호와 글자를 함께 쓴다(docs/dev_rules.md의 Admin 웹 UI).

const dateTimeFormat = new Intl.DateTimeFormat("ko-KR", {dateStyle: "medium", timeStyle: "short"});

export function formatDateTime(ms: number): string {
  return dateTimeFormat.format(new Date(ms));
}

export const SANCTION_LABELS: Record<SanctionType, string> = {
  warning: "⚠ 경고",
  chatRestriction: "💬 채팅 제한",
  suspension: "⛔ 이용 정지",
  permanentBan: "🚫 영구 정지",
};

export const ACTION_LABELS: Record<ReportAction, string> = {
  dismissed: "○ 무혐의",
  ...SANCTION_LABELS,
};

export const REPORT_STATUS_LABELS: Record<ReportStatus, string> = {
  pending: "⏳ 처리 전",
  resolved: "✓ 처리함",
};

export const CHANNEL_LABELS: Record<ChatChannel, string> = {
  lobby: "로비 채팅",
  game: "대국 채팅",
  spectator: "관전 채팅",
};

/** 급수 1~27을 "18급"~"9단"으로 바꾼다(docs/game/rank.md). */
export function formatRank(rankLevel: number): string {
  return rankLevel <= 18 ? `${19 - rankLevel}급` : `${rankLevel - 18}단`;
}

/** 제재 기간. 기간이 없는 제재(경고, 영구 정지)는 null. */
export function formatDuration(durationDays: number | null): string | null {
  return durationDays === null ? null : `${durationDays}일`;
}

/** 지금 걸린 제재의 끝. 경고는 끝이 없고, 영구 정지는 "영구"다. */
export function formatSanctionEnd(type: SanctionType, endsAt: number | null, now: number): string {
  if (type === "warning") {
    return "앱에서 확인하면 사라짐";
  }
  if (endsAt === null) {
    return "영구";
  }
  return endsAt > now ? `${formatDateTime(endsAt)}까지` : `${formatDateTime(endsAt)}에 끝남`;
}

/** 분류별 점수를 높은 것부터. */
export function getSortedScores(scores: Record<string, number>): [string, number][] {
  return Object.entries(scores).sort((a, b) => b[1] - a[1]);
}
