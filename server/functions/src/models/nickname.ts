import {Timestamp} from "firebase-admin/firestore";

/** Firestore `nicknames/{nicknameKey}`. 닉네임 중복을 막는 예약 문서다(서버 전용). */
export interface Nickname {
  uid: string;
  createdAt: Timestamp;
}

/**
 * 닉네임을 쓸 수 없는 이유. `checkNickname` 응답과 `createProfile` 오류의 `details.code`로 앱에 보낸다.
 * 앱의 `NicknameRejectReason`과 값을 일치시킨다. 옛 앱이 받으므로 값을 추가하지 않는다(docs/dev_rules.md의 커밋과 배포).
 */
export const NicknameRejectReason = {
  invalidFormat: "invalidFormat",
  taken: "taken",
  bannedWord: "bannedWord",
  impersonation: "impersonation",
} as const;
export type NicknameRejectReason = (typeof NicknameRejectReason)[keyof typeof NicknameRejectReason];
