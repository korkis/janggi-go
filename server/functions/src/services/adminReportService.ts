import dayjs from "dayjs";
import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {ADMIN_PAGE_SIZE, MODERATION_LOG_RETENTION_DAYS} from "../config";
import {AdminErrorCode, Page, PageCursor, ReportAction, ReportSummaryView, ReportWithTargetView} from "../models/admin";
import {ReportStatus} from "../models/report";
import {runTransaction} from "../repositories/firestore";
import {
  getPendingReportsForMessageInTransaction,
  getReport,
  getReportInTransaction,
  getReportsPage,
  resolveReportInTransaction,
} from "../repositories/reportsRepository";
import {getUsers} from "../repositories/usersRepository";
import {getUserPrivateInTransaction} from "../repositories/usersPrivateRepository";
import {getUserHistory} from "./adminUserService";
import {toReportDetailView, toReportSummaryView} from "./adminViewService";
import {applySanctionInTransaction} from "./sanctionService";

/** 신고 목록 한 쪽. 처리 전은 오래된 것부터, 처리한 신고는 최근에 처리한 것부터다. */
export async function getReports(status: ReportStatus, cursor: PageCursor | null): Promise<Page<ReportSummaryView>> {
  const entries = await getReportsPage(status, cursor, ADMIN_PAGE_SIZE);
  const users = await getUsers(entries.flatMap((entry) => [entry.report.reporterUid, entry.report.targetUid]));
  const last = entries[entries.length - 1];
  let nextCursor: PageCursor | null = null;
  if (entries.length === ADMIN_PAGE_SIZE && last !== undefined) {
    const sortedAt = status === ReportStatus.pending ? last.report.createdAt : last.report.resolvedAt;
    nextCursor = {afterMs: sortedAt!.toMillis(), afterId: last.reportId};
  }
  return {items: entries.map((entry) => toReportSummaryView(entry, users)), nextCursor};
}

/** 신고 상세와 피신고자의 지난 기록. 없으면 notFound. */
export async function getReportWithTarget(reportId: string): Promise<ReportWithTargetView> {
  const report = await getReport(reportId);
  if (report === null) {
    throw new HttpsError("not-found", "신고가 없습니다", {code: AdminErrorCode.notFound});
  }
  const [users, target] = await Promise.all([
    getUsers([report.reporterUid, report.targetUid]),
    getUserHistory(report.targetUid),
  ]);
  return {report: toReportDetailView({reportId, report}, users), target};
}

/**
 * 신고를 처리한다(docs/moderation.md의 Admin 웹 처리). 무혐의면 닫기만 하고, 제재면 피신고자에게 제재를 건다.
 * 같은 메시지에 대한 다른 처리 전 신고도 같은 결과로 닫는다. 이미 처리한 신고면 alreadyResolved로 거절해 제재가 두 번 걸리지 않게 한다.
 * 처리한 신고는 1년 뒤 TTL 정책으로 지운다. 결과는 바뀐 신고 상세다.
 */
export async function resolveReport(
  adminUid: string,
  reportId: string,
  action: ReportAction,
  durationDays: number | null,
  reason: string,
): Promise<ReportWithTargetView> {
  const now = dayjs();
  const resolvedAt = Timestamp.fromDate(now.toDate());
  const expiresAt = Timestamp.fromDate(now.add(MODERATION_LOG_RETENTION_DAYS, "day").toDate());
  const result = await runTransaction(async (transaction) => {
    const report = await getReportInTransaction(transaction, reportId);
    if (report === null) {
      throw new HttpsError("not-found", "신고가 없습니다", {code: AdminErrorCode.notFound});
    }
    if (report.status !== ReportStatus.pending) {
      throw new HttpsError("failed-precondition", "이미 처리한 신고입니다", {code: AdminErrorCode.alreadyResolved});
    }
    const sameMessage = await getPendingReportsForMessageInTransaction(transaction, report.message.messageId);
    let sanctionId: string | null = null;
    if (action !== "dismissed") {
      const userPrivate = await getUserPrivateInTransaction(transaction, report.targetUid);
      if (userPrivate === null) {
        throw new HttpsError("not-found", "피신고자가 없습니다", {code: AdminErrorCode.notFound});
      }
      sanctionId = applySanctionInTransaction(
        transaction,
        {uid: report.targetUid, type: action, durationDays, reason, reportId, adminUid},
        userPrivate,
        now,
      );
    }
    const reportIds = new Set([reportId, ...sameMessage.map((entry) => entry.reportId)]);
    for (const id of reportIds) {
      resolveReportInTransaction(transaction, id, {action, reason, adminUid, sanctionId}, resolvedAt, expiresAt);
    }
    return {targetUid: report.targetUid, sanctionId, resolvedCount: reportIds.size};
  });
  logger.info("resolveReport 완료", {adminUid, reportId, action, durationDays, ...result});
  return getReportWithTarget(reportId);
}
