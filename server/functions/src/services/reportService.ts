import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {REPORT_CONTEXT_MESSAGES} from "../config";
import {ChatChannel, ChatErrorCode} from "../models/chat";
import {ReportStatus, ReportedMessage} from "../models/report";
import {getChatCheck} from "../repositories/chatChecksRepository";
import {
  ChatMessageEntry,
  getMessage,
  getMessagesAfter,
  getMessagesBefore,
} from "../repositories/chatMessagesRepository";
import {createReportIfAbsent, getReportId} from "../repositories/reportsRepository";
import {requireChatAccess} from "./chatAccessService";

function toReportedMessage(entry: ChatMessageEntry): ReportedMessage {
  const {uid, nickname, text, sentAt} = entry.message;
  return {messageId: entry.messageId, uid, nickname, text, sentAt};
}

/**
 * 채팅 메시지를 신고한다(docs/server.md의 reportMessage). 신고된 메시지와 앞뒤 메시지, 검사 결과의 사본으로 `reports`를 만든다.
 * 채팅이 90일 뒤 지워져도 처리가 끝날 때까지 남기기 위해 사본을 둔다. 같은 사람이 같은 메시지를 다시 신고하면 그대로 둔다.
 */
export async function reportMessage(
  reporterUid: string,
  channel: ChatChannel,
  gameId: string | null,
  messageId: string,
): Promise<void> {
  await requireChatAccess(reporterUid, channel, gameId);
  const message = await getMessage(channel, gameId, messageId);
  if (message === null) {
    throw new HttpsError("not-found", "메시지가 없습니다", {code: ChatErrorCode.notFound});
  }
  if (message.uid === reporterUid) {
    throw new HttpsError("permission-denied", "내 메시지는 신고할 수 없습니다", {code: ChatErrorCode.notAllowed});
  }
  const [before, after, check] = await Promise.all([
    getMessagesBefore(channel, gameId, messageId, REPORT_CONTEXT_MESSAGES),
    getMessagesAfter(channel, gameId, messageId, REPORT_CONTEXT_MESSAGES),
    getChatCheck(messageId),
  ]);
  const reportId = getReportId(messageId, reporterUid);
  const created = await createReportIfAbsent(reportId, {
    reporterUid,
    targetUid: message.uid,
    channel,
    gameId,
    message: toReportedMessage({messageId, message}),
    context: [...before, ...after].map(toReportedMessage),
    check: check === null ? null : {scores: check.scores, bannedWordMatched: check.bannedWordMatched},
    status: ReportStatus.pending,
    resolution: null,
    createdAt: Timestamp.now(),
    resolvedAt: null,
    expiresAt: null,
  });
  logger.info("reportMessage 완료", {reporterUid, targetUid: message.uid, channel, gameId, reportId, created});
}
