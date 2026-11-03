import type {User} from "firebase/auth";
import {create} from "zustand";
import {getAdminClaims, getCurrentUser, signInWithGoogle, signOutUser, watchAuthUser} from "../services/authService";

/**
 * - loading: 로그인 복원이나 claim 확인 중이다. 보호 라우트를 그리지 않는다.
 * - signedOut: 로그인하지 않았다.
 * - notAdmin: 로그인했지만 ID token에 `admin: true` claim이 없다.
 * - admin: 관리자다.
 */
export type AuthStatus = "loading" | "signedOut" | "notAdmin" | "admin";

interface AuthState {
  status: AuthStatus;
  uid: string | null;
  // 화면 위쪽에 보여주는 로그인한 계정. 메모리에만 둔다.
  email: string | null;
  // 로그인이나 claim 확인이 실패했을 때 보여줄 문구.
  errorMessage: string | null;
  // 로그인 창이나 claim 다시 확인이 진행 중이다. 버튼을 막는다.
  busy: boolean;
  /** 로그인 상태를 듣기 시작한다. 그만 들으려면 돌려준 함수를 부른다. */
  start: () => () => void;
  signIn: () => Promise<void>;
  signOut: () => Promise<void>;
  /** 새 ID token을 받아 admin claim을 다시 확인한다. 방금 관리자로 지정된 경우에 쓴다. */
  recheck: () => Promise<void>;
}

// 로그인 상태가 빠르게 여러 번 바뀌면 마지막 확인 결과만 쓰기 위한 번호.
let checkSequence = 0;

export const useAuthStore = create<AuthState>()((set) => {
  async function applyUser(user: User | null, forceRefresh: boolean): Promise<void> {
    const sequence = ++checkSequence;
    if (user === null) {
      set({status: "signedOut", uid: null, email: null});
      return;
    }
    set({status: "loading", uid: user.uid, email: user.email});
    try {
      const claims = await getAdminClaims(forceRefresh);
      if (sequence !== checkSequence) {
        return;
      }
      set({status: claims?.admin === true ? "admin" : "notAdmin", errorMessage: null});
    } catch (error) {
      console.error("admin claim 확인 실패", {code: (error as {code?: unknown}).code});
      if (sequence === checkSequence) {
        set({status: "notAdmin", errorMessage: "권한을 확인하지 못했어요. 다시 확인해 주세요."});
      }
    }
  }

  return {
    status: "loading",
    uid: null,
    email: null,
    errorMessage: null,
    busy: false,
    start: () => watchAuthUser((user) => void applyUser(user, false)),
    signIn: async () => {
      try {
        set({busy: true, errorMessage: null});
        await signInWithGoogle();
      } catch (error) {
        const code = (error as {code?: unknown}).code;
        console.error("로그인 실패", {code});
        if (code !== "auth/popup-closed-by-user" && code !== "auth/cancelled-popup-request") {
          set({errorMessage: "로그인하지 못했어요. 다시 시도해 주세요."});
        }
      } finally {
        set({busy: false});
      }
    },
    signOut: async () => {
      try {
        set({busy: true});
        await signOutUser();
      } finally {
        set({busy: false});
      }
    },
    recheck: async () => {
      try {
        set({busy: true, errorMessage: null});
        await applyUser(getCurrentUser(), true);
      } finally {
        set({busy: false});
      }
    },
  };
});
