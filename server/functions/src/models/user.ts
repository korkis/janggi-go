import {Timestamp} from "firebase-admin/firestore";

export interface UserStats {
  games: number;
  wins: number;
  losses: number;
}

/**
 * Firestore `users/{uid}`. 다른 사용자에게도 보이는 공개 프로필이다.
 * 필드는 앱의 `UserProfile`(app/lib/models/user_profile.dart)과 일치시킨다.
 */
export interface User {
  nickname: string;
  // 급수. 1이 18급, 27이 9단이다(docs/database.md의 공통 enum).
  rankLevel: number;
  stats: UserStats;
  createdAt: Timestamp;
  // 회원 탈퇴를 누른 시각. 없거나 null이면 탈퇴하지 않았다(docs/database.md의 회원 탈퇴).
  deletedAt?: Timestamp | null;
}
