import {HttpsError, onCall} from "firebase-functions/https";
import {UserHistoryView} from "../models/admin";
import {restoreAccount} from "../services/accountService";
import {isValidDocumentId, validateReason} from "./adminParams";
import {requireAdmin} from "./auth";

interface AdminRestoreAccountParams {
  uid: string;
  // 되돌리는 사유. 로그에만 남긴다.
  reason: string;
}

function validateParams(requestParams: AdminRestoreAccountParams): void {
  if (!isValidDocumentId(requestParams?.uid)) {
    throw new HttpsError("invalid-argument", "uid가 올바르지 않습니다");
  }
  validateReason(requestParams.reason);
}

/** 탈퇴를 되돌린다(docs/server.md의 회원 탈퇴). 결과는 바뀐 사용자 기록이다. */
export const adminRestoreAccount = onCall<AdminRestoreAccountParams>(async (request): Promise<UserHistoryView> => {
  const requestParams = request.data;
  const adminUid = requireAdmin(request);
  validateParams(requestParams);
  return restoreAccount(adminUid, requestParams.uid, requestParams.reason.trim());
});
