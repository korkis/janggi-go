import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {ReportAction, ReportWithTargetView} from "../models/admin";
import {resolveReport} from "../services/adminReportService";
import {isValidDocumentId, validateReason, validateSanction} from "./adminParams";
import {requireAdmin} from "./auth";

interface AdminResolveReportParams {
  reportId: string;
  action: ReportAction;
  // 채팅 제한과 이용 정지의 기간(일). 그 밖의 조치는 null이나 없음이다.
  durationDays?: number | null;
  // 조치 사유. 제재면 사용자에게 보인다.
  reason: string;
}

function validateParams(requestParams: AdminResolveReportParams): void {
  if (!isValidDocumentId(requestParams?.reportId)) {
    throw new HttpsError("invalid-argument", "reportId가 올바르지 않습니다");
  }
  if (requestParams.action === "dismissed") {
    if ((requestParams.durationDays ?? null) !== null) {
      throw new HttpsError("invalid-argument", "durationDays가 올바르지 않습니다");
    }
  } else {
    validateSanction(requestParams.action, requestParams.durationDays);
  }
  validateReason(requestParams.reason);
}

/** 신고를 처리한다. 무혐의로 닫거나 피신고자에게 제재를 건다. 결과는 바뀐 신고 상세다. */
export const adminResolveReport = onCall<AdminResolveReportParams>(async (request): Promise<ReportWithTargetView> => {
  const requestParams = request.data;
  const adminUid = requireAdmin(request);
  validateParams(requestParams);
  logger.debug("adminResolveReport 시작", {adminUid, reportId: requestParams.reportId, action: requestParams.action});
  return resolveReport(
    adminUid,
    requestParams.reportId,
    requestParams.action,
    requestParams.durationDays ?? null,
    requestParams.reason.trim(),
  );
});
