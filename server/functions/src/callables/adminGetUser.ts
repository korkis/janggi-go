import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {UserHistoryView} from "../models/admin";
import {findUidByNickname, getUserHistory} from "../services/adminUserService";
import {isValidDocumentId} from "./adminParams";
import {requireAdmin} from "./auth";

// 닉네임으로 찾을 때 받는 최대 글자 수. 닉네임 규칙(10자)보다 넉넉하게 둔다.
const NICKNAME_QUERY_MAX_LENGTH = 50;

/** uid나 닉네임 중 하나로 찾는다. */
interface AdminGetUserParams {
  uid?: string | null;
  nickname?: string | null;
}

function validateParams(requestParams: AdminGetUserParams): void {
  const uid: unknown = requestParams?.uid ?? null;
  const nickname: unknown = requestParams?.nickname ?? null;
  if ((uid === null) === (nickname === null)) {
    throw new HttpsError("invalid-argument", "uid와 nickname 중 하나만 줘야 합니다");
  }
  if (uid !== null && !isValidDocumentId(uid)) {
    throw new HttpsError("invalid-argument", "uid가 올바르지 않습니다");
  }
  if (
    nickname !== null &&
    (typeof nickname !== "string" || !isValidDocumentId(nickname.trim()) || nickname.length > NICKNAME_QUERY_MAX_LENGTH)
  ) {
    throw new HttpsError("invalid-argument", "nickname이 올바르지 않습니다");
  }
}

/** Admin 웹의 사용자 조회. 프로필, 지금 걸린 제재, 최근 제재·신고·검사 기록·닉네임 변경을 돌려준다. 없으면 notFound. */
export const adminGetUser = onCall<AdminGetUserParams>(async (request): Promise<UserHistoryView> => {
  const requestParams = request.data;
  const adminUid = requireAdmin(request);
  validateParams(requestParams);
  const nickname = requestParams.nickname ?? null;
  const uid = nickname === null ? requestParams.uid! : await findUidByNickname(nickname.trim());
  const user = await getUserHistory(uid);
  logger.info("adminGetUser 완료", {adminUid, uid});
  return user;
});
