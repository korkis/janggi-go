import {FieldPath, Query, QuerySnapshot, Timestamp, Transaction, getFirestore} from "firebase-admin/firestore";
import {PageCursor} from "../models/admin";
import {Report, ReportResolution, ReportStatus} from "../models/report";
import {modelConverter} from "./firestore";

const COLLECTION = "reports";

/** 신고와 그 ID. */
export interface ReportEntry {
  reportId: string;
  report: Report;
}

function reportsCollection() {
  return getFirestore().collection(COLLECTION).withConverter(modelConverter<Report>());
}

function toEntries(snapshot: QuerySnapshot<Report>): ReportEntry[] {
  return snapshot.docs.map((doc) => ({reportId: doc.id, report: doc.data()}));
}

/** 같은 사람이 같은 메시지를 여러 번 신고해도 신고 하나로 남기도록 메시지와 신고한 사람으로 ID를 정한다. */
export function getReportId(messageId: string, reporterUid: string): string {
  return `${messageId}_${reporterUid}`;
}

/** 신고를 만든다. 이미 있으면 그대로 두고 false를 돌려준다. */
export async function createReportIfAbsent(reportId: string, report: Report): Promise<boolean> {
  try {
    await reportsCollection().doc(reportId).create(report);
    return true;
  } catch (error) {
    // 이미 있으면 ALREADY_EXISTS(6)로 실패한다.
    if ((error as {code?: unknown}).code === 6) {
      return false;
    }
    throw error;
  }
}

export async function getReport(reportId: string): Promise<Report | null> {
  const snapshot = await reportsCollection().doc(reportId).get();
  return snapshot.data() ?? null;
}

export async function getReportInTransaction(transaction: Transaction, reportId: string): Promise<Report | null> {
  const snapshot = await transaction.get(reportsCollection().doc(reportId));
  return snapshot.data() ?? null;
}

/**
 * 신고 목록 한 쪽. 처리 전 신고는 오래된 것부터(대기열), 처리한 신고는 최근에 처리한 것부터 읽는다.
 * 색인: `status` + `createdAt` 오름차순, `status` + `resolvedAt` 내림차순(server/firestore.indexes.json).
 */
export async function getReportsPage(
  status: ReportStatus,
  cursor: PageCursor | null,
  limit: number,
): Promise<ReportEntry[]> {
  const pending = status === ReportStatus.pending;
  const field = pending ? "createdAt" : "resolvedAt";
  const direction = pending ? "asc" : "desc";
  let query: Query<Report> = reportsCollection()
    .where("status", "==", status)
    .orderBy(field, direction)
    .orderBy(FieldPath.documentId(), direction);
  if (cursor !== null) {
    query = query.startAfter(Timestamp.fromMillis(cursor.afterMs), cursor.afterId);
  }
  return toEntries(await query.limit(limit).get());
}

/** [targetUid]가 신고된 최근 기록. 색인: `targetUid` + `createdAt` 내림차순. */
export async function getReportsByTarget(targetUid: string, limit: number): Promise<ReportEntry[]> {
  const snapshot = await reportsCollection()
    .where("targetUid", "==", targetUid)
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();
  return toEntries(snapshot);
}

/** 같은 메시지에 대한 처리 전 신고. 여러 사람이 같은 메시지를 신고했으면 한 번에 처리하기 위해서다. 같음 조건만이라 복합 색인이 없어도 된다. */
export async function getPendingReportsForMessageInTransaction(
  transaction: Transaction,
  messageId: string,
): Promise<ReportEntry[]> {
  const query = reportsCollection()
    .where("message.messageId", "==", messageId)
    .where("status", "==", ReportStatus.pending);
  return toEntries(await transaction.get(query));
}

/** 신고를 처리한 것으로 바꾼다. [expiresAt]에 TTL 정책으로 지운다. */
export function resolveReportInTransaction(
  transaction: Transaction,
  reportId: string,
  resolution: ReportResolution,
  resolvedAt: Timestamp,
  expiresAt: Timestamp,
): void {
  transaction.update(reportsCollection().doc(reportId), {
    status: ReportStatus.resolved,
    resolution,
    resolvedAt,
    expiresAt,
  });
}
