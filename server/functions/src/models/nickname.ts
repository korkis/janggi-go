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

/**
 * 닉네임 변경을 막는 이유. `changeNickname` 오류의 `details.code`로 앱에 보낸다. 닉네임 자체의 문제는 NicknameRejectReason으로
 * 보낸다. 앱의 `AppErrorCode`와 값을 일치시킨다.
 */
export const NicknameChangeErrorCode = {
  // 닉네임을 아직 정하지 않았다.
  profileRequired: "profileRequired",
  // 바꾼 지 7일이 지나지 않았다.
  nicknameChangeCooldown: "nicknameChangeCooldown",
  // 무료 변경을 이미 썼다. 엽전으로 바꾸는 기능은 아직 없다.
  nicknameChangeNotFree: "nicknameChangeNotFree",
} as const;
export type NicknameChangeErrorCode = (typeof NicknameChangeErrorCode)[keyof typeof NicknameChangeErrorCode];

/** Firestore `nickname_changes/{changeId}`. Admin 웹에서 보는 닉네임 변경 기록이다(서버 전용). */
export interface NicknameChange {
  uid: string;
  before: string;
  after: string;
  changedAt: Timestamp;
}
