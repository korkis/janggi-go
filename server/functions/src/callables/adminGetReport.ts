import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {ReportWithTargetView} from "../models/admin";
import {getReportWithTarget} from "../services/adminReportService";
import {isValidDocumentId} from "./adminParams";
import {requireAdmin} from "./auth";

interface AdminGetReportParams {
  reportId: string;
}

function validateParams(requestParams: AdminGetReportParams): void {
  if (!isValidDocumentId(requestParams?.reportId)) {
    throw new HttpsError("invalid-argument", "reportId가 올바르지 않습니다");
  }
}

/** Admin 웹의 신고 상세. 신고된 메시지와 앞뒤 대화, 검사 결과, 피신고자의 지난 신고·검사 기록·제재 이력을 함께 돌려준다. */
export const adminGetReport = onCall<AdminGetReportParams>(async (request): Promise<ReportWithTargetView> => {
  const requestParams = request.data;
  const adminUid = requireAdmin(request);
  validateParams(requestParams);
  const result = await getReportWithTarget(requestParams.reportId);
  logger.info("adminGetReport 완료", {adminUid, reportId: requestParams.reportId});
  return result;
});
