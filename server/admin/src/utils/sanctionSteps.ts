import type {SanctionType, SanctionView} from "../models/admin";

/** 제재 하나의 종류와 기간. 채팅 제한과 이용 정지만 기간이 있다. */
export interface SanctionChoice {
  type: SanctionType;
  durationDays: number | null;
}

/**
 * 제재 단계 경고 → 1일 → 7일 → 30일 → 영구 정지(docs/moderation.md의 제재 단계와 안내). 기간 단계는 채팅 신고 처리에 맞춰
 * 채팅 제한으로 제안하고, 관리자가 이용 정지로 바꾸거나 단계를 건너뛸 수 있다.
 */
export const SANCTION_STEPS: SanctionChoice[] = [
  {type: "warning", durationDays: null},
  {type: "chatRestriction", durationDays: 1},
  {type: "chatRestriction", durationDays: 7},
  {type: "chatRestriction", durationDays: 30},
  {type: "permanentBan", durationDays: null},
];

/** 지난 제재 수로 고른 다음 단계. 제재가 없으면 경고, 네 번 이상이면 영구 정지다. */
export function getNextSanctionStep(sanctions: SanctionView[]): {step: number; choice: SanctionChoice} {
  const step = Math.min(sanctions.length, SANCTION_STEPS.length - 1);
  return {step, choice: SANCTION_STEPS[step]!};
}

export function isTimedSanction(type: SanctionType): boolean {
  return type === "chatRestriction" || type === "suspension";
}
