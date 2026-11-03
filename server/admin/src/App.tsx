import {useEffect} from "react";
import {BrowserRouter, Navigate, Route, Routes} from "react-router";
import {Layout} from "./components/Layout";
import {RequireAdmin} from "./components/RequireAdmin";
import {ConfigPage} from "./pages/ConfigPage";
import {LoginPage} from "./pages/LoginPage";
import {ModerationLogsPage} from "./pages/ModerationLogsPage";
import {ReportDetailPage} from "./pages/ReportDetailPage";
import {ReportsPage} from "./pages/ReportsPage";
import {UserPage} from "./pages/UserPage";
import {UserSearchPage} from "./pages/UserSearchPage";
import {useAuthStore} from "./stores/authStore";
import {useConfigStore} from "./stores/configStore";
import {useModerationStore} from "./stores/moderationStore";
import {useUiStore} from "./stores/uiStore";

export function App() {
  const start = useAuthStore((state) => state.start);
  const status = useAuthStore((state) => state.status);

  useEffect(() => start(), [start]);

  // 관리자가 아니게 되면(로그아웃 등) 읽어 둔 신고·채팅 내용을 메모리에서 지운다.
  useEffect(() => {
    if (status === "signedOut" || status === "notAdmin") {
      useModerationStore.getState().reset();
      useConfigStore.getState().reset();
      useUiStore.getState().clearNotice();
    }
  }, [status]);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<RequireAdmin />}>
          <Route element={<Layout />}>
            <Route path="/reports" element={<ReportsPage />} />
            <Route path="/reports/:reportId" element={<ReportDetailPage />} />
            <Route path="/moderation-logs" element={<ModerationLogsPage />} />
            <Route path="/users" element={<UserSearchPage />} />
            <Route path="/users/:uid" element={<UserPage />} />
            <Route path="/config" element={<ConfigPage />} />
          </Route>
        </Route>
        <Route path="*" element={<Navigate to="/reports" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
