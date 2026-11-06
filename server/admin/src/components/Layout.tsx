import {NavLink, Outlet} from "react-router";
import {USE_FIREBASE_EMULATOR} from "../config";
import {useAuthStore} from "../stores/authStore";
import {useUiStore} from "../stores/uiStore";

const NAV_ITEMS = [
  {to: "/reports", label: "신고"},
  {to: "/moderation-logs", label: "검사 기록"},
  {to: "/users", label: "사용자"},
  {to: "/coins", label: "엽전"},
  {to: "/config", label: "설정"},
];

/** 로그인한 관리자 화면의 틀. 위쪽 메뉴, 로그인한 계정, 조치 결과 알림을 둔다. */
export function Layout() {
  const email = useAuthStore((state) => state.email);
  const busy = useAuthStore((state) => state.busy);
  const signOut = useAuthStore((state) => state.signOut);
  const notice = useUiStore((state) => state.notice);
  const clearNotice = useUiStore((state) => state.clearNotice);

  return (
    <div className="min-h-screen">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-4 px-4 py-3">
          <span className="font-bold">장기고 Admin</span>
          {USE_FIREBASE_EMULATOR && (
            <span className="rounded bg-amber-200 px-2 py-0.5 text-xs font-semibold text-amber-900">에뮬레이터</span>
          )}
          <nav className="flex gap-1">
            {NAV_ITEMS.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                className={({isActive}) =>
                  `rounded-md px-3 py-1.5 text-sm ${isActive ? "bg-slate-900 text-white" : "hover:bg-slate-100"}`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
          <span className="ml-auto text-sm text-slate-600">{email}</span>
          <button
            type="button"
            onClick={() => void signOut()}
            disabled={busy}
            className="rounded-md border border-slate-300 px-3 py-1.5 text-sm hover:bg-slate-100 disabled:opacity-50"
          >
            로그아웃
          </button>
        </div>
      </header>
      {notice !== null && (
        <div
          role="status"
          className={`mx-auto mt-4 flex max-w-6xl items-center justify-between rounded-lg px-4 py-2 text-sm ${
            notice.kind === "success" ? "bg-emerald-50 text-emerald-900" : "bg-red-50 text-red-900"
          }`}
        >
          <span>
            {notice.kind === "success" ? "✓ " : "⚠ "}
            {notice.text}
          </span>
          <button type="button" onClick={clearNotice} className="text-xs underline">
            닫기
          </button>
        </div>
      )}
      <main className="mx-auto max-w-6xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}
