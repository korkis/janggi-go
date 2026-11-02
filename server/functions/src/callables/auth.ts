import {CallableRequest, HttpsError} from "firebase-functions/https";

/** 로그인한 호출자의 uid. 로그인하지 않았으면 unauthenticated 오류를 던진다. */
export function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다");
  }
  return uid;
}
