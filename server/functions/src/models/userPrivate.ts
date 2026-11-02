import {Timestamp} from "firebase-admin/firestore";

export const SanctionType = {
  warning: "warning",
  chatRestriction: "chatRestriction",
  suspension: "suspension",
  permanentBan: "permanentBan",
} as const;
export type SanctionType = (typeof SanctionType)[keyof typeof SanctionType];

export interface ActiveSanction {
  type: SanctionType;
  // 영구 정지면 null.
  endsAt: Timestamp | null;
  reason: string;
}

/** Firestore `users_private/{uid}`. 본인만 보는 정보다. */
export interface UserPrivate {
  challengesEnabled: boolean;
  // 현재 급수 구간 안에서의 위치 0~1.
  rankProgress: number;
  // 다음 급수까지의 어림 승수. 9단이거나 아직 급수 대국을 두지 않았으면 null.
  winsToNextRank: number | null;
  nicknameChangeCount: number;
  nicknameChangedAt: Timestamp | null;
  sanction: ActiveSanction | null;
}
