import {createHash, timingSafeEqual} from "node:crypto";
import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {defineSecret} from "firebase-functions/params";
import {RevenueCatEvent} from "../models/store";
import {InvalidRevenueCatEventError, handleRevenueCatEvent} from "../services/purchaseService";

// RevenueCat 대시보드의 웹훅 Authorization 헤더 값. Secret Manager에 두고, 에뮬레이터는 server/functions/.secret.local에서 읽는다.
const webhookAuth = defineSecret("REVENUECAT_WEBHOOK_AUTH");

/** 헤더가 비밀값과 같은지. 길이가 달라도 시간 차가 나지 않게 해시를 비교한다. 비밀값이 비어 있으면 모두 거절한다. */
function isAuthorized(header: string | undefined, secret: string): boolean {
  if (header === undefined || secret.length === 0) {
    return false;
  }
  const digest = (value: string) => createHash("sha256").update(value).digest();
  return timingSafeEqual(digest(header), digest(secret));
}

/**
 * RevenueCat이 구매와 환불을 알리는 주소(docs/server.md의 앱 결제). 200이 아니면 RevenueCat이 80분 동안 다섯 번까지 다시 보낸다.
 * 엽전과 상품은 여기서만 지급하고 돌려받는다.
 */
export const revenueCatWebhook = onRequest({secrets: [webhookAuth], invoker: "public"}, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).send();
    return;
  }
  if (!isAuthorized(request.headers.authorization, webhookAuth.value())) {
    logger.warn("revenueCatWebhook 인증 실패");
    response.status(401).send();
    return;
  }
  const event = (request.body as {event?: RevenueCatEvent} | undefined)?.event;
  if (typeof event !== "object" || event === null) {
    response.status(400).send();
    return;
  }
  try {
    await handleRevenueCatEvent(event);
    response.status(200).send();
  } catch (error) {
    if (error instanceof InvalidRevenueCatEventError) {
      logger.error("revenueCatWebhook 잘못된 요청", {id: event.id, message: error.message});
      response.status(400).send();
      return;
    }
    logger.error("revenueCatWebhook 실패", {id: event.id, error});
    response.status(500).send();
  }
});
