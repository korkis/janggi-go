import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {reportMessage as reportMessageInDb} from "../services/reportService";
import {requireUid, requireWebAllowed} from "./auth";
import {ChatTargetParams, isValidKey, validateChatTarget} from "./chatParams";

interface ReportMessageParams extends ChatTargetParams {
  messageId: string;
}

function validateParams(requestParams: ReportMessageParams): void {
  // 타입 선언과 달리 앱이 무엇이든 보낼 수 있으므로 실행 중에 다시 확인한다.
  validateChatTarget(requestParams);
  if (!isValidKey(requestParams.messageId)) {
    throw new HttpsError("invalid-argument", "messageId가 올바르지 않습니다");
  }
}

/** 채팅 메시지를 신고한다. 신고된 메시지와 앞뒤 메시지, 검사 결과를 함께 저장한다. */
export const reportMessage = onCall<ReportMessageParams>(async (request): Promise<Record<string, never>> => {
  const requestParams = request.data;
  const uid = requireUid(request);
  await requireWebAllowed(request);
  validateParams(requestParams);
  const gameId = requestParams.gameId ?? null;
  logger.debug("reportMessage 시작", {uid, channel: requestParams.channel, gameId});
  await reportMessageInDb(uid, requestParams.channel, gameId, requestParams.messageId);
  return {};
});
