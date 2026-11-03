import {Navigate, Outlet, useLocation} from "react-router";
import {useAuthStore} from "../stores/authStore";
import {Loading} from "./States";

/**
 * 보호 라우트. Firebase Auth 복원과 admin claim 확인이 끝난 뒤에만 안쪽 화면을 그린다(docs/dev_rules.md의 Admin 웹 규칙).
 * 화면의 확인과 별개로 모든 Callable이 서버에서 claim을 다시 확인한다.
 */
export function RequireAdmin() {
  const status = useAuthStore((state) => state.status);
  const location = useLocation();
  if (status === "loading") {
    return <Loading text="로그인과 권한을 확인하는 중…" />;
  }
  if (status !== "admin") {
    return <Navigate to="/login" replace state={{from: location.pathname + location.search}} />;
  }
  return <Outlet />;
}
