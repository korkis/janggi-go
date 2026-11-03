import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {Page, PageCursor, ReportSummaryView} from "../models/admin";
import {ReportStatus} from "../models/report";
import {getReports} from "../services/adminReportService";
import {validateCursor} from "./adminParams";
import {requireAdmin} from "./auth";

interface AdminGetReportsParams {
  status: ReportStatus;
  // 다음 쪽이면 앞 쪽 응답의 nextCursor. 첫 쪽이면 없다.
  cursor?: PageCursor | null;
}

function validateParams(requestParams: AdminGetReportsParams): void {
  const status: unknown = requestParams?.status;
  if (typeof status !== "string" || !Object.values<string>(ReportStatus).includes(status)) {
    throw new HttpsError("invalid-argument", "status가 올바르지 않습니다");
  }
  validateCursor(requestParams.cursor);
}

/** Admin 웹의 신고 목록. 처리 전은 오래된 것부터, 처리한 신고는 최근에 처리한 것부터 한 쪽씩 읽는다. */
export const adminGetReports = onCall<AdminGetReportsParams>(async (request): Promise<Page<ReportSummaryView>> => {
  const requestParams = request.data;
  const adminUid = requireAdmin(request);
  validateParams(requestParams);
  const page = await getReports(requestParams.status, requestParams.cursor ?? null);
  logger.info("adminGetReports 완료", {adminUid, status: requestParams.status, count: page.items.length});
  return page;
});
