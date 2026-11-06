import {Timestamp} from "firebase-admin/firestore";

/** `deleteAccount`와 `createProfile`이 탈퇴 때문에 거절한 이유. 오류의 `details.code`로 앱에 보낸다. */
export const AccountErrorCode = {
  // 진행 중(상차림 포함)인 대국이 있다.
  inGame: "inGame",
  // 대기열, 방, 신청에 남아 있다.
  busy: "busy",
  // 제재가 남은 채 지워진 계정이라 아직 가입할 수 없다.
  signupBlocked: "signupBlocked",
} as const;
export type AccountErrorCode = (typeof AccountErrorCode)[keyof typeof AccountErrorCode];

/** Firestore `deleted_accounts/{identityHash}`. 제재가 남은 채로 지워진 계정의 재가입을 막는 기록이다(서버 전용). */
export interface DeletedAccount {
  // 이 시각까지 다시 가입할 수 없다. 영구 정지면 null이고 지우지 않는다. TTL 정책으로 지운다.
  expiresAt: Timestamp | null;
  createdAt: Timestamp;
}

/**
 * Firestore `player_states/{uid}` 중 탈퇴를 처리할 때 보는 필드. 대국 서버가 쓰고 Functions는 읽기만 한다. 전체 모양은
 * 대국 서버의 `PlayerState`(server/game/lib/models/player_state.dart)다.
 */
export interface PlayerState {
  roomId?: string | null;
  gameId?: string | null;
  outgoingChallengeId?: string | null;
  incomingChallengeId?: string | null;
  quickQueueJoinedAt?: Timestamp | null;
}
