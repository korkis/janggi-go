import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {defineSecret} from "firebase-functions/params";
import {CHAT_MAX_LENGTH} from "../config";
import {sendChatMessage as sendChatMessageInDb} from "../services/chatService";
import {requireUid, requireWebAllowed} from "./auth";
import {ChatTargetParams, validateChatTarget} from "./chatParams";

// OpenAI API 키. Secret Manager에 두고, 에뮬레이터는 server/functions/.secret.local에서 읽는다.
const openAiApiKey = defineSecret("OPENAI_API_KEY");

interface SendChatMessageParams extends ChatTargetParams {
  text: string;
}

interface SendChatMessageResult {
  messageId: string;
}

/** 앞뒤 공백을 지우고 줄바꿈과 이어진 공백을 한 칸으로 줄인다. 채팅은 한 줄로 보여준다. */
function normalizeText(text: string): string {
  return text.trim().replace(/\s+/g, " ");
}

function validateParams(requestParams: SendChatMessageParams): void {
  // 타입 선언과 달리 앱이 무엇이든 보낼 수 있으므로 실행 중에 다시 확인한다.
  validateChatTarget(requestParams);
  const text: unknown = requestParams.text;
  if (typeof text !== "string") {
    throw new HttpsError("invalid-argument", "text가 없습니다");
  }
  const length = [...normalizeText(text)].length;
  if (length === 0 || length > CHAT_MAX_LENGTH) {
    throw new HttpsError("invalid-argument", "text 길이가 올바르지 않습니다");
  }
}

/** 채팅 메시지를 검사해 통과하면 저장한다. 검사에 걸리면 `details.code`가 messageBlocked인 오류로 거절한다. */
export const sendChatMessage = onCall<SendChatMessageParams>(
  {secrets: [openAiApiKey]},
  async (request): Promise<SendChatMessageResult> => {
    const requestParams = request.data;
    const uid = requireUid(request);
    await requireWebAllowed(request);
    validateParams(requestParams);
    const gameId = requestParams.gameId ?? null;
    logger.debug("sendChatMessage 시작", {uid, channel: requestParams.channel, gameId});
    const messageId = await sendChatMessageInDb(
      uid,
      requestParams.channel,
      gameId,
      normalizeText(requestParams.text),
      openAiApiKey.value(),
    );
    return {messageId};
  },
);
