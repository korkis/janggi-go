import {useEffect} from "react";
import {Link, useSearchParams} from "react-router";
import {ActionBadge, ReportStatusBadge} from "../components/Badges";
import {Empty, ErrorState, Loading} from "../components/States";
import {REPORT_STATUSES, type ReportStatus} from "../models/admin";
import {useModerationStore} from "../stores/moderationStore";
import {CHANNEL_LABELS, REPORT_STATUS_LABELS, formatDateTime} from "../utils/format";

/** URL의 `status`. 없거나 모르는 값이면 처리 전이다. */
function getStatus(value: string | null): ReportStatus {
  return (REPORT_STATUSES as readonly string[]).includes(value ?? "") ? (value as ReportStatus) : "pending";
}

/** 신고 대기열(처리 전, 오래된 것부터)과 처리한 신고(최근 처리 순). */
export function ReportsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const status = getStatus(searchParams.get("status"));
  const list = useModerationStore((state) => state.reports[status]);
  const loadReports = useModerationStore((state) => state.loadReports);

  useEffect(() => {
    if (list.status === "idle") {
      void loadReports(status, false);
    }
  }, [list.status, loadReports, status]);

  return (
    <div>
      <div className="flex items-center gap-2">
        <h1 className="text-xl font-bold">신고</h1>
        <div role="tablist" className="ml-4 flex gap-1">
          {REPORT_STATUSES.map((value) => (
            <button
              key={value}
              type="button"
              role="tab"
              aria-selected={status === value}
              onClick={() => setSearchParams({status: value})}
              className={`rounded-md px-3 py-1.5 text-sm ${status === value ? "bg-slate-900 text-white" : "hover:bg-slate-100"}`}
            >
              {REPORT_STATUS_LABELS[value]}
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={() => void loadReports(status, false)}
          disabled={list.status === "loading"}
          className="ml-auto rounded-md border border-slate-300 px-3 py-1.5 text-sm hover:bg-slate-100 disabled:opacity-50"
        >
          새로 고침
        </button>
      </div>

      {(list.status === "idle" || list.status === "loading") && <Loading />}
      {list.status === "error" && list.error !== null && (
        <ErrorState error={list.error} onRetry={() => void loadReports(status, false)} />
      )}
      {list.status === "loaded" && list.items.length === 0 && (
        <Empty text={status === "pending" ? "처리할 신고가 없어요" : "처리한 신고가 없어요"} />
      )}
      {list.status === "loaded" && list.items.length > 0 && (
        <table className="mt-4 w-full table-fixed border-collapse overflow-hidden rounded-xl bg-white text-sm shadow-sm">
          <thead className="bg-slate-100 text-left text-xs text-slate-600">
            <tr>
              <th className="w-28 p-2">상태</th>
              <th className="p-2">신고된 메시지</th>
              <th className="w-36 p-2">보낸 사람</th>
              <th className="w-36 p-2">신고한 사람</th>
              <th className="w-24 p-2">채팅</th>
              <th className="w-40 p-2">{status === "pending" ? "신고 시각" : "처리 시각"}</th>
            </tr>
          </thead>
          <tbody>
            {list.items.map((item) => (
              <tr key={item.reportId} className="border-t border-slate-100 hover:bg-slate-50">
                <td className="p-2">
                  {item.action === null ? (
                    <ReportStatusBadge status={item.status} />
                  ) : (
                    <ActionBadge action={item.action} />
                  )}
                </td>
                <td className="truncate p-2">
                  <Link to={`/reports/${encodeURIComponent(item.reportId)}`} className="hover:underline">
                    “{item.messageText}”
                  </Link>
                </td>
                <td className="truncate p-2">{item.targetNickname ?? item.targetUid}</td>
                <td className="truncate p-2">{item.reporterNickname ?? item.reporterUid}</td>
                <td className="p-2">{CHANNEL_LABELS[item.channel]}</td>
                <td className="p-2 text-xs">{formatDateTime(item.resolvedAt ?? item.createdAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {list.error !== null && list.status === "loaded" && <ErrorState error={list.error} />}
      {list.status === "loaded" && list.nextCursor !== null && (
        <button
          type="button"
          onClick={() => void loadReports(status, true)}
          disabled={list.loadingMore}
          className="mt-4 w-full rounded-md border border-slate-300 py-2 text-sm hover:bg-slate-100 disabled:opacity-50"
        >
          {list.loadingMore ? "불러오는 중…" : "더 보기"}
        </button>
      )}
    </div>
  );
}
