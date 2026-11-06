import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {NicknameRejectReason} from "../models/nickname";
import {getNickname} from "../repositories/nicknamesRepository";
import {findNicknameProblem, getNicknameKey} from "../services/nicknameService";
import {requireUid, requireWebAllowed} from "./auth";

// 입력하는 동안 부르는 확인이라 형식이 틀려도 오류가 아니라 결과로 돌려준다. 이보다 길면 요청 자체를 거절한다.
const MAX_REQUEST_NICKNAME_LENGTH = 100;

interface CheckNicknameParams {
  nickname: string;
}

interface CheckNicknameResult {
  available: boolean;
  // 쓸 수 없으면 그 이유. 쓸 수 있으면 null.
  reason: NicknameRejectReason | null;
}

function validateParams(requestParams: CheckNicknameParams): void {
  // 타입 선언과 달리 앱이 무엇이든 보낼 수 있으므로 실행 중에 다시 확인한다.
  const nickname: unknown = requestParams?.nickname;
  if (typeof nickname !== "string" || nickname.length > MAX_REQUEST_NICKNAME_LENGTH) {
    throw new HttpsError("invalid-argument", "nickname이 올바르지 않습니다");
  }
}

/** 닉네임 정하기 화면에서 입력하는 동안 닉네임을 쓸 수 있는지 확인한다. 형식, 사칭 단어, 금칙어, 중복을 본다. */
export const checkNickname = onCall<CheckNicknameParams>(async (request): Promise<CheckNicknameResult> => {
  const requestParams = request.data;
  const uid = requireUid(request);
  await requireWebAllowed(request);
  validateParams(requestParams);

  const problem = findNicknameProblem(requestParams.nickname);
  if (problem !== null) {
    logger.info("checkNickname 완료", {uid, available: false, reason: problem});
    return {available: false, reason: problem};
  }
  const reservation = await getNickname(getNicknameKey(requestParams.nickname));
  if (reservation !== null && reservation.uid !== uid) {
    logger.info("checkNickname 완료", {uid, available: false, reason: NicknameRejectReason.taken});
    return {available: false, reason: NicknameRejectReason.taken};
  }
  logger.info("checkNickname 완료", {uid, available: true});
  return {available: true, reason: null};
});
