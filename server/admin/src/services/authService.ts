import {type User, onAuthStateChanged, signInWithEmailAndPassword, signOut} from "firebase/auth";
import type {AdminClaims} from "../models/admin";
import {auth} from "./firebase";

// Firebase Auth 로그인과 admin claim 확인. 화면은 authStore를 거쳐 쓴다.

/** 로그인 상태가 바뀔 때마다(처음 복원 포함) [listener]를 부른다. 그만 들으려면 돌려준 함수를 부른다. */
export function watchAuthUser(listener: (user: User | null) => void): () => void {
  return onAuthStateChanged(auth, listener);
}

export function getCurrentUser(): User | null {
  return auth.currentUser;
}

export async function signInWithEmail(email: string, password: string): Promise<void> {
  await signInWithEmailAndPassword(auth, email, password);
}

export async function signOutUser(): Promise<void> {
  await signOut(auth);
}

/**
 * 로그인한 사용자 ID token의 custom claim에서 admin 여부를 읽는다. [forceRefresh]면 새 ID token을 받아 방금 준 claim도 반영한다.
 * claim이 boolean true일 때만 관리자로 본다. 로그인하지 않았으면 null.
 */
export async function getAdminClaims(forceRefresh: boolean): Promise<AdminClaims | null> {
  const user = auth.currentUser;
  if (user === null) {
    return null;
  }
  const result = await user.getIdTokenResult(forceRefresh);
  const admin: unknown = result.claims.admin;
  return {admin: admin === true};
}
