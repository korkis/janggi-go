import dayjs from "dayjs";
import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {CHAT_RETENTION_DAYS, MODERATION_LOG_RETENTION_DAYS} from "../config";
import {ChatChannel, ChatErrorCode} from "../models/chat";
import {createChatCheck} from "../repositories/chatChecksRepository";
import {getAppConfig} from "../repositories/configsRepository";
import {createMessage, createMessageId} from "../repositories/chatMessagesRepository";
import {createModerationLog} from "../repositories/moderationLogsRepository";
import {getUser} from "../repositories/usersRepository";
import {getUserPrivate} from "../repositories/usersPrivateRepository";
import {requireChatAccess, requireNotChatSanctioned} from "./chatAccessService";
import {checkChatText} from "./chatModerationService";
import {ModerationApiError} from "./openAiModeration";

/**
 * 채팅 메시지를 검사해 저장하고 메시지 ID를 돌려준다(docs/server.md의 sendChatMessage).
 *
 * `chatEnabled`가 꺼져 있으면 `featureDisabled`로 거절한다. 권한, 프로필, 제재를 확인한 뒤 금칙어와 OpenAI Moderation으로 검사한다. 통과하면 `chat_checks`와 채팅 경로에 쓴다.
 * 걸리면 저장하지 않고 `moderation_logs`에 남긴 뒤 messageBlocked로 거절한다.
 */
export async function sendChatMessage(
  uid: string,
  channel: ChatChannel,
  gameId: string | null,
  text: string,
  apiKey: string,
): Promise<string> {
  const [user, userPrivate, {chatEnabled}] = await Promise.all([getUser(uid), getUserPrivate(uid), getAppConfig()]);
  if (!chatEnabled) {
    throw new HttpsError("failed-precondition", "지금은 채팅을 받지 않습니다", {code: ChatErrorCode.featureDisabled});
  }
  if (user === null || user.deletedAt != null) {
    throw new HttpsError("failed-precondition", "닉네임을 먼저 정해야 합니다", {code: ChatErrorCode.profileRequired});
  }
  requireNotChatSanctioned(userPrivate);
  await requireChatAccess(uid, channel, gameId);

  let check;
  try {
    check = await checkChatText(text, apiKey);
  } catch (error) {
    logger.error("sendChatMessage 검사 실패", {uid, channel, gameId, status: (error as ModerationApiError).status});
    throw new HttpsError("unavailable", "메시지를 검사하지 못했습니다", {code: ChatErrorCode.moderationUnavailable});
  }
  const now = dayjs();
  if (!check.passed) {
    const logId = await createModerationLog({
      uid,
      channel,
      gameId,
      text,
      categories: check.categories,
      scores: check.scores,
      bannedWordMatched: check.bannedWordMatched,
      createdAt: Timestamp.fromDate(now.toDate()),
      expiresAt: Timestamp.fromDate(now.add(MODERATION_LOG_RETENTION_DAYS, "day").toDate()),
    });
    logger.info("sendChatMessage 거절", {
      uid,
      channel,
      gameId,
      logId,
      categories: check.categories,
      bannedWordMatched: check.bannedWordMatched,
    });
    throw new HttpsError("failed-precondition", "검사에 걸린 메시지입니다", {code: ChatErrorCode.messageBlocked});
  }

  const messageId = createMessageId(channel, gameId);
  // 신고할 때 검사 결과를 함께 저장하도록 메시지보다 먼저 쓴다.
  await createChatCheck(messageId, {
    scores: check.scores,
    bannedWordMatched: false,
    expiresAt: Timestamp.fromDate(now.add(CHAT_RETENTION_DAYS, "day").toDate()),
  });
  await createMessage(channel, gameId, messageId, {uid, nickname: user.nickname, text, sentAt: now.valueOf()});
  logger.info("sendChatMessage 완료", {uid, channel, gameId, messageId});
  return messageId;
}
