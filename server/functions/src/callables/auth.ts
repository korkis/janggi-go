import {CallableRequest, HttpsError} from "firebase-functions/https";
import {FeatureErrorCode} from "../models/feature";
import {getAppConfig} from "../repositories/configsRepository";

/** 로그인한 호출자의 uid. 로그인하지 않았으면 unauthenticated 오류를 던진다. */
export function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다");
  }
  return uid;
}

/**
 * 웹을 멈췄으면 웹에서 온 호출을 `featureDisabled`로 거절한다(docs/server.md의 운영 스위치). 브라우저는 `Origin` 헤더를 언제나 붙이고
 * 앱(안드로이드, iOS)은 붙이지 않는다. 앱이 쓰는 Callable이 부른다. Admin 웹도 브라우저이므로 Admin Callable은 부르지 않는다.
 */
export async function requireWebAllowed(request: CallableRequest): Promise<void> {
  if (request.rawRequest.headers?.origin === undefined) {
    return;
  }
  const {webEnabled} = await getAppConfig();
  if (!webEnabled) {
    throw new HttpsError("failed-precondition", "지금은 웹을 쓸 수 없습니다", {code: FeatureErrorCode.featureDisabled});
  }
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
