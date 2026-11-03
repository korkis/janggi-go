import {HttpsError, onCall} from "firebase-functions/https";
import {UserHistoryView} from "../models/admin";
import {SanctionType} from "../models/userPrivate";
import {sanctionUser} from "../services/adminUserService";
import {isValidDocumentId, validateReason, validateSanction} from "./adminParams";
import {requireAdmin} from "./auth";

interface AdminSanctionUserParams {
  uid: string;
  type: SanctionType;
  // 채팅 제한과 이용 정지의 기간(일). 경고와 영구 정지는 null이나 없음이다.
  durationDays?: number | null;
  // 사용자에게 보이는 사유.
  reason: string;
}

function validateParams(requestParams: AdminSanctionUserParams): void {
  if (!isValidDocumentId(requestParams?.uid)) {
    throw new HttpsError("invalid-argument", "uid가 올바르지 않습니다");
  }
  validateSanction(requestParams.type, requestParams.durationDays);
  validateReason(requestParams.reason);
}

/** 신고 없이 사용자에게 제재를 건다. 결과는 바뀐 사용자 정보다. */
export const adminSanctionUser = onCall<AdminSanctionUserParams>(async (request): Promise<UserHistoryView> => {
  const requestParams = request.data;
  const adminUid = requireAdmin(request);
  validateParams(requestParams);
  return sanctionUser({
    uid: requestParams.uid,
    type: requestParams.type,
    durationDays: requestParams.durationDays ?? null,
    reason: requestParams.reason.trim(),
    reportId: null,
    adminUid,
  });
});
