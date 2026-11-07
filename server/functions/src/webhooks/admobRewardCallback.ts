import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {InvalidAdmobCallbackError, receiveAdmobCallback} from "../services/rewardedAdService";

/** 요청 주소에서 쿼리 문자열을 그대로 꺼낸다. 서명을 확인하려면 디코딩하지 않은 글자가 필요하다. */
function getRawQuery(url: string): string {
  const queryAt = url.indexOf("?");
  return queryAt < 0 ? "" : url.slice(queryAt + 1);
}

/**
 * 사용자가 보상형 광고를 다 보면 AdMob이 부르는 주소(서버 측 검증, docs/server.md의 앱 광고). 광고 엽전은 여기서만 준다.
 * 200이 아니면 구글이 1초 간격으로 다섯 번까지 다시 보낸다.
 */
export const admobRewardCallback = onRequest({invoker: "public"}, async (request, response) => {
  if (request.method !== "GET") {
    response.status(405).send();
    return;
  }
  try {
    await receiveAdmobCallback(getRawQuery(request.originalUrl));
    response.status(200).send();
  } catch (error) {
    if (error instanceof InvalidAdmobCallbackError) {
      logger.warn("admobRewardCallback 서명 실패", {message: error.message});
      response.status(403).send();
      return;
    }
    logger.error("admobRewardCallback 실패", {error});
    response.status(500).send();
  }
});
