import * as logger from "firebase-functions/logger";
import {ModerationScores} from "../models/chat";
import {hasBannedWord} from "./bannedWordService";
import {ModerationApiError, moderateWithOpenAi} from "./openAiModeration";

/** 채팅 메시지 한 개의 검사 결과. */
export interface ChatTextCheck {
  passed: boolean;
  // 걸린 OpenAI 분류.
  categories: string[];
  scores: ModerationScores;
  bannedWordMatched: boolean;
}

/**
 * 자체 금칙어와 OpenAI Moderation으로 [text]를 검사한다(docs/moderation.md의 메시지 검사).
 * 금칙어에 걸리면 OpenAI에 보내지 않는다. OpenAI를 부르지 못하면 ModerationApiError를 던진다. 검사하지 못한 메시지는 저장하지 않는다.
 */
export async function checkChatText(text: string, apiKey: string): Promise<ChatTextCheck> {
  if (hasBannedWord(text)) {
    return {passed: false, categories: [], scores: {}, bannedWordMatched: true};
  }
  try {
    const result = await moderateWithOpenAi(text, apiKey);
    return {passed: !result.flagged, categories: result.categories, scores: result.scores, bannedWordMatched: false};
  } catch (error) {
    if (error instanceof ModerationApiError && error.isPermissionError()) {
      // 키가 없거나 Moderations 권한이 없다. 운영자가 Secret Manager의 OPENAI_API_KEY를 확인해야 한다.
      logger.error("OpenAI Moderation 권한 오류. OPENAI_API_KEY와 Moderations 권한을 확인한다", {status: error.status});
    }
    throw error;
  }
}
