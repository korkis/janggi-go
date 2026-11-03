import {HttpsError} from "firebase-functions/https";
import {ADMIN_REASON_MAX_LENGTH, SANCTION_DURATION_DAYS} from "../config";
import {PageCursor} from "../models/admin";
import {SanctionType} from "../models/userPrivate";

// Admin Callable이 함께 쓰는 요청 파라미터 확인. 타입 선언과 달리 무엇이든 올 수 있으므로 실행 중에 다시 확인한다.

// Firestore 문서 ID로 쓰는 uid와 신고 ID의 형식. 경로를 벗어나는 `/`를 막는다.
const DOCUMENT_ID_PATTERN = /^[^/]{1,200}$/;

/** [value]가 Firestore 문서 ID로 쓸 수 있는 문자열인지. */
export function isValidDocumentId(value: unknown): value is string {
  return typeof value === "string" && DOCUMENT_ID_PATTERN.test(value) && value !== "." && value !== "..";
}

/** 목록의 다음 쪽 위치를 확인한다. 첫 쪽이면 null이나 없음이다. */
export function validateCursor(cursor: unknown): void {
  if (cursor === undefined || cursor === null) {
    return;
  }
  const {afterMs, afterId} = cursor as Partial<PageCursor>;
  if (!Number.isInteger(afterMs) || !isValidDocumentId(afterId)) {
    throw new HttpsError("invalid-argument", "cursor가 올바르지 않습니다");
  }
}

/** 조치 사유. 앞뒤 공백을 지우고 1~ADMIN_REASON_MAX_LENGTH자여야 한다. 사유는 제재 팝업으로 사용자에게 보인다. */
export function validateReason(reason: unknown): void {
  if (typeof reason !== "string") {
    throw new HttpsError("invalid-argument", "reason이 없습니다");
  }
  const length = reason.trim().length;
  if (length === 0 || length > ADMIN_REASON_MAX_LENGTH) {
    throw new HttpsError("invalid-argument", "reason 길이가 올바르지 않습니다");
  }
}

/** 제재 종류와 기간. 채팅 제한과 이용 정지는 SANCTION_DURATION_DAYS의 기간이 있어야 하고, 경고와 영구 정지는 없어야 한다. */
export function validateSanction(type: unknown, durationDays: unknown): void {
  if (typeof type !== "string" || !Object.values<string>(SanctionType).includes(type)) {
    throw new HttpsError("invalid-argument", "type이 올바르지 않습니다");
  }
  const timed = type === SanctionType.chatRestriction || type === SanctionType.suspension;
  const days = durationDays ?? null;
  if (timed ? !SANCTION_DURATION_DAYS.includes(days as number) : days !== null) {
    throw new HttpsError("invalid-argument", "durationDays가 올바르지 않습니다");
  }
}
