import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {changeNickname as changeNicknameInDb} from "../services/profileService";
import {findNicknameProblem} from "../services/nicknameService";
import {requireUid, requireWebAllowed} from "./auth";

interface ChangeNicknameParams {
  nickname: string;
  // 무료 변경을 이미 쓴 사용자가 앱에서 본 값. 이 값을 냈다는 뜻이다. 옛 앱은 보내지 않는다.
  coinCost?: number;
}

/** 형식, 사칭 단어, 금칙어를 검사한다. 걸리면 `details.code`에 NicknameRejectReason을 담아 거절한다. */
function validateParams(requestParams: ChangeNicknameParams): void {
  // 타입 선언과 달리 앱이 무엇이든 보낼 수 있으므로 실행 중에 다시 확인한다.
  const nickname: unknown = requestParams?.nickname;
  if (typeof nickname !== "string") {
    throw new HttpsError("invalid-argument", "nickname이 없습니다");
  }
  const coinCost: unknown = requestParams.coinCost;
  if (coinCost !== undefined && coinCost !== null && (!Number.isInteger(coinCost) || (coinCost as number) < 0)) {
    throw new HttpsError("invalid-argument", "coinCost가 올바르지 않습니다");
  }
  const problem = findNicknameProblem(nickname);
  if (problem !== null) {
    throw new HttpsError("invalid-argument", "쓸 수 없는 닉네임입니다", {code: problem});
  }
}

/** 닉네임을 바꾼다. 바꾼 뒤 7일 동안은 다시 바꿀 수 없고, 첫 변경은 무료이며 두 번째부터 엽전을 낸다(docs/screens.md의 내 정보). */
export const changeNickname = onCall<ChangeNicknameParams>(async (request): Promise<Record<string, never>> => {
  const requestParams = request.data;
  const uid = requireUid(request);
  await requireWebAllowed(request);
  validateParams(requestParams);
  logger.debug("changeNickname 시작", {uid});
  await changeNicknameInDb(uid, requestParams.nickname, requestParams.coinCost ?? null);
  return {};
});
