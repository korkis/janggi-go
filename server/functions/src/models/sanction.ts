import {Timestamp} from "firebase-admin/firestore";
import {SanctionType} from "./userPrivate";

/** Firestore `sanctions/{sanctionId}`. 제재 이력이다(서버 전용). 지금 걸린 제재는 `users_private.sanction`에도 쓴다. */
export interface Sanction {
  uid: string;
  type: SanctionType;
  startsAt: Timestamp;
  // 영구 정지와 경고는 null.
  endsAt: Timestamp | null;
  // 사용자에게 보이는 사유.
  reason: string;
  // 신고를 처리하며 건 제재면 그 신고.
  reportId: string | null;
  // 자동 제재면 null.
  adminUid: string | null;
  createdAt: Timestamp;
}
