import dayjs, {Dayjs} from "dayjs";
import * as logger from "firebase-functions/logger";
import {CHAT_CLEANUP_BATCH_SIZE, CHAT_RETENTION_DAYS} from "../config";
import {ChatChannel} from "../models/chat";
import {
  GameChatChannel,
  deleteGameChat,
  deleteLobbyMessages,
  getChatGameIds,
  getLatestMessage,
  getOldLobbyMessageIds,
} from "../repositories/chatMessagesRepository";

/**
 * 보관 기간(90일)이 지난 RTDB 채팅을 지운다(docs/moderation.md의 보관 기간). 하루 한 번 예약 작업이 부른다.
 *
 * 로비 채팅은 `sentAt`이 지난 메시지를 지운다. 대국·관전 채팅은 한 대국의 채팅이 대국 시간 안에 끝나므로 마지막 메시지가 지난 대국의
 * 채팅을 통째로 지운다.
 */
export async function cleanupChats(now: Dayjs = dayjs()): Promise<{lobbyMessages: number; gameChats: number}> {
  const cutoff = now.subtract(CHAT_RETENTION_DAYS, "day").valueOf();
  let lobbyMessages = 0;
  for (;;) {
    const messageIds = await getOldLobbyMessageIds(cutoff, CHAT_CLEANUP_BATCH_SIZE);
    if (messageIds.length === 0) {
      break;
    }
    await deleteLobbyMessages(messageIds);
    lobbyMessages += messageIds.length;
  }
  let gameChats = 0;
  for (const channel of [ChatChannel.game, ChatChannel.spectator] as GameChatChannel[]) {
    const gameIds = await getChatGameIds(channel);
    logger.debug("cleanupChats 대국 채팅 확인", {channel, count: gameIds.length});
    for (const gameId of gameIds) {
      const latest = await getLatestMessage(channel, gameId);
      if (latest === null || latest.sentAt < cutoff) {
        await deleteGameChat(channel, gameId);
        gameChats += 1;
      }
    }
  }
  logger.info("cleanupChats 완료", {lobbyMessages, gameChats});
  return {lobbyMessages, gameChats};
}
