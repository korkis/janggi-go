import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {changeNickname as changeNicknameInDb} from "../services/profileService";
import {findNicknameProblem} from "../services/nicknameService";
import {requireUid} from "./auth";

interface ChangeNicknameParams {
  nickname: string;
}

/** 형식, 사칭 단어, 금칙어를 검사한다. 걸리면 `details.code`에 NicknameRejectReason을 담아 거절한다. */
function validateParams(requestParams: ChangeNicknameParams): void {
  // 타입 선언과 달리 앱이 무엇이든 보낼 수 있으므로 실행 중에 다시 확인한다.
  const nickname: unknown = requestParams?.nickname;
  if (typeof nickname !== "string") {
    throw new HttpsError("invalid-argument", "nickname이 없습니다");
  }
  const problem = findNicknameProblem(nickname);
  if (problem !== null) {
    throw new HttpsError("invalid-argument", "쓸 수 없는 닉네임입니다", {code: problem});
  }
}

/** 닉네임을 바꾼다. 바꾼 뒤 7일 동안은 다시 바꿀 수 없고, 지금은 첫 변경(무료)만 할 수 있다(docs/screens.md의 내 정보). */
export const changeNickname = onCall<ChangeNicknameParams>(async (request): Promise<Record<string, never>> => {
  const requestParams = request.data;
  const uid = requireUid(request);
  validateParams(requestParams);
  logger.debug("changeNickname 시작", {uid});
  await changeNicknameInDb(uid, requestParams.nickname);
  return {};
});
