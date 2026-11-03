import {Timestamp} from "firebase-admin/firestore";
import {ModerationLogView, ReportDetailView, ReportMessageView, ReportSummaryView, SanctionView} from "../models/admin";
import {ReportedMessage} from "../models/report";
import {User} from "../models/user";
import {ModerationLogEntry} from "../repositories/moderationLogsRepository";
import {ReportEntry} from "../repositories/reportsRepository";
import {SanctionEntry} from "../repositories/sanctionsRepository";

// Firestore 문서를 Admin Callable 응답 모양으로 바꾼다. 시각은 epoch ms로 보낸다.

function toMillis(timestamp: Timestamp | null): number | null {
  return timestamp === null ? null : timestamp.toMillis();
}

function toMessageView(message: ReportedMessage): ReportMessageView {
  const {messageId, uid, nickname, text, sentAt} = message;
  return {messageId, uid, nickname, text, sentAt};
}

/** [users]는 신고한 사람과 신고된 사람의 지금 프로필이다. 없는 사람은 닉네임을 null로 보낸다. */
export function toReportSummaryView(entry: ReportEntry, users: Map<string, User>): ReportSummaryView {
  const {report} = entry;
  return {
    reportId: entry.reportId,
    status: report.status,
    channel: report.channel,
    reporterUid: report.reporterUid,
    reporterNickname: users.get(report.reporterUid)?.nickname ?? null,
    targetUid: report.targetUid,
    targetNickname: users.get(report.targetUid)?.nickname ?? null,
    messageText: report.message.text,
    createdAt: report.createdAt.toMillis(),
    resolvedAt: toMillis(report.resolvedAt),
    action: report.resolution?.action ?? null,
  };
}

export function toReportDetailView(entry: ReportEntry, users: Map<string, User>): ReportDetailView {
  const {report} = entry;
  const resolution = report.resolution;
  return {
    ...toReportSummaryView(entry, users),
    gameId: report.gameId,
    message: toMessageView(report.message),
    context: report.context.map(toMessageView),
    check: report.check,
    resolution:
      resolution === null
        ? null
        : {
            action: resolution.action,
            reason: resolution.reason,
            adminUid: resolution.adminUid,
            sanctionId: resolution.sanctionId,
          },
  };
}

export function toSanctionView(entry: SanctionEntry): SanctionView {
  const {sanction} = entry;
  return {
    sanctionId: entry.sanctionId,
    type: sanction.type,
    startsAt: sanction.startsAt.toMillis(),
    endsAt: toMillis(sanction.endsAt),
    reason: sanction.reason,
    reportId: sanction.reportId,
    adminUid: sanction.adminUid,
    createdAt: sanction.createdAt.toMillis(),
  };
}

export function toModerationLogView(entry: ModerationLogEntry, users: Map<string, User>): ModerationLogView {
  const {log} = entry;
  return {
    logId: entry.logId,
    uid: log.uid,
    nickname: users.get(log.uid)?.nickname ?? null,
    channel: log.channel,
    gameId: log.gameId,
    text: log.text,
    categories: log.categories,
    scores: log.scores,
    bannedWordMatched: log.bannedWordMatched,
    createdAt: log.createdAt.toMillis(),
  };
}
