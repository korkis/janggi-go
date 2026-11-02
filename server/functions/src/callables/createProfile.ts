import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {createProfile as createProfileInDb} from "../services/profileService";
import {findNicknameProblem} from "../services/nicknameService";
import {requireUid} from "./auth";

interface CreateProfileParams {
  nickname: string;
}

/** 형식, 사칭 단어, 금칙어를 검사한다. 걸리면 `details.code`에 NicknameRejectReason을 담아 거절한다. */
function validateParams(requestParams: CreateProfileParams): void {
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

/** 첫 가입 때 닉네임을 정하고 프로필을 만든다. 급수는 18급에서 시작한다. */
export const createProfile = onCall<CreateProfileParams>(async (request): Promise<Record<string, never>> => {
  const requestParams = request.data;
  const uid = requireUid(request);
  validateParams(requestParams);
  logger.debug("createProfile 시작", {uid});
  await createProfileInDb(uid, requestParams.nickname);
  return {};
});
