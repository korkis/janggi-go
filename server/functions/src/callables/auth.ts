import {CallableRequest, HttpsError} from "firebase-functions/https";

/** 로그인한 호출자의 uid. 로그인하지 않았으면 unauthenticated 오류를 던진다. */
export function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다");
  }
  return uid;
}

/**
 * Admin 웹 호출자의 uid. 로그인하지 않았으면 unauthenticated, ID token에 `admin: true` claim이 없으면 permission-denied를 던진다.
 * Admin 웹이 화면에서 claim을 확인해도 모든 Admin Callable이 여기서 다시 확인한다(docs/dev_rules.md의 Admin 웹 규칙).
 */
export function requireAdmin(request: CallableRequest): string {
  const uid = requireUid(request);
  if (request.auth?.token.admin !== true) {
    throw new HttpsError("permission-denied", "관리자가 아닙니다");
  }
  return uid;
}
