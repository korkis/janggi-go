import {type FormEvent, useState} from "react";
import {Navigate, useLocation} from "react-router";
import {USE_FIREBASE_EMULATOR} from "../config";
import {Loading} from "../components/States";
import {useAuthStore} from "../stores/authStore";

/** 라우트 state로 받은 돌아갈 주소. 없거나 모양이 다르면 신고 목록이다. */
function getReturnPath(state: unknown): string {
  if (typeof state === "object" && state !== null) {
    const from = (state as Record<string, unknown>).from;
    if (typeof from === "string" && from.startsWith("/") && !from.startsWith("/login")) {
      return from;
    }
  }
  return "/reports";
}

/** 로그인과 권한 없음 화면. 관리자로 확인되면 원래 가려던 화면으로 보낸다. */
export function LoginPage() {
  const {status, email, errorMessage, busy, signIn, signOut, recheck} = useAuthStore();
  const location = useLocation();
  const [loginEmail, setLoginEmail] = useState("");
  const [password, setPassword] = useState("");

  function submit(event: FormEvent): void {
    event.preventDefault();
    void signIn(loginEmail.trim(), password);
  }

  if (status === "admin") {
    return <Navigate to={getReturnPath(location.state)} replace />;
  }

  return (
    <div className="mx-auto mt-24 max-w-sm rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
      <h1 className="text-xl font-bold">장기고 Admin</h1>
      {USE_FIREBASE_EMULATOR && (
        <p className="mt-1 text-xs text-amber-800">에뮬레이터에 연결되어 있어요. 운영 데이터가 아니에요.</p>
      )}
      {status === "loading" && <Loading text="로그인을 확인하는 중…" />}
      {status === "signedOut" && (
        <form onSubmit={submit} className="mt-4 space-y-3">
          <label className="block text-sm">
            <span className="font-medium">이메일</span>
            <input
              type="email"
              autoComplete="username"
              required
              value={loginEmail}
              onChange={(event) => setLoginEmail(event.target.value)}
              className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1"
            />
          </label>
          <label className="block text-sm">
            <span className="font-medium">비밀번호</span>
            <input
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1"
            />
          </label>
          <button
            type="submit"
            disabled={busy}
            className="w-full rounded-md bg-slate-900 py-2 text-sm font-semibold text-white disabled:opacity-50"
          >
            로그인
          </button>
        </form>
      )}
      {status === "notAdmin" && (
        <div role="alert" className="mt-4 text-sm">
          <p className="font-semibold">🔒 관리자 권한이 없어요</p>
          <p className="mt-1 text-slate-600">
            {email} 계정에는 admin 권한이 없어요. 방금 지정받았다면 권한을 다시 확인해 주세요.
          </p>
          <div className="mt-4 flex gap-2">
            <button
              type="button"
              onClick={() => void recheck()}
              disabled={busy}
              className="flex-1 rounded-md bg-slate-900 py-2 font-semibold text-white disabled:opacity-50"
            >
              권한 다시 확인
            </button>
            <button
              type="button"
              onClick={() => void signOut()}
              disabled={busy}
              className="flex-1 rounded-md border border-slate-300 py-2 disabled:opacity-50"
            >
              로그아웃
            </button>
          </div>
        </div>
      )}
      {errorMessage !== null && (
        <p role="alert" className="mt-3 text-sm text-red-700">
          ⚠ {errorMessage}
        </p>
      )}
    </div>
  );
}
