import {useEffect} from "react";
import {Link, useSearchParams} from "react-router";
import {ScoreList} from "../components/ScoreList";
import {Empty, ErrorState, Loading} from "../components/States";
import {useModerationStore} from "../stores/moderationStore";
import {CHANNEL_LABELS, formatDateTime} from "../utils/format";

/** 검사 기록. 금칙어와 OpenAI Moderation에 걸려 저장하지 않은 메시지를 최근 것부터 보여준다. `?uid=`로 한 사람만 본다. */
export function ModerationLogsPage() {
  const [searchParams] = useSearchParams();
  const uid = searchParams.get("uid");
  const list = useModerationStore((state) => state.moderationLogs[uid ?? ""]);
  const loadModerationLogs = useModerationStore((state) => state.loadModerationLogs);

  useEffect(() => {
    void loadModerationLogs(uid, false);
  }, [loadModerationLogs, uid]);

  return (
    <div>
      <div className="flex items-center gap-2">
        <h1 className="text-xl font-bold">검사 기록</h1>
        {uid !== null && (
          <span className="ml-2 text-sm">
            <span className="font-mono">{uid}</span>의 기록 ·{" "}
            <Link to="/moderation-logs" className="text-blue-700 underline">
              모두 보기
            </Link>
          </span>
        )}
        <button
          type="button"
          onClick={() => void loadModerationLogs(uid, false)}
          disabled={list?.status === "loading"}
          className="ml-auto rounded-md border border-slate-300 px-3 py-1.5 text-sm hover:bg-slate-100 disabled:opacity-50"
        >
          새로 고침
        </button>
      </div>
      <p className="mt-1 text-sm text-slate-600">검사에 걸려 채팅에 저장하지 않은 메시지예요. 1년 보관해요.</p>

      {(list === undefined || list.status === "idle" || list.status === "loading") && <Loading />}
      {list?.status === "error" && list.error !== null && (
        <ErrorState error={list.error} onRetry={() => void loadModerationLogs(uid, false)} />
      )}
      {list?.status === "loaded" && list.items.length === 0 && <Empty text="검사에 걸린 메시지가 없어요" />}
      {list?.status === "loaded" && (
        <ul className="mt-4 space-y-3">
          {list.items.map((log) => (
            <li key={log.logId} className="rounded-xl border border-slate-200 bg-white p-4">
              <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500">
                <Link
                  to={`/users/${encodeURIComponent(log.uid)}`}
                  className="text-sm font-semibold text-slate-900 underline"
                >
                  {log.nickname ?? log.uid}
                </Link>
                <span>{CHANNEL_LABELS[log.channel]}</span>
                {log.gameId !== null && <span className="font-mono">대국 {log.gameId}</span>}
                <span className="ml-auto">{formatDateTime(log.createdAt)}</span>
              </div>
              <p className="mt-2 whitespace-pre-wrap">“{log.text}”</p>
              <p className="mt-2 text-sm">
                {log.bannedWordMatched ? (
                  <span className="font-semibold text-red-700">● 자체 금칙어에 걸림</span>
                ) : (
                  <span>
                    ● OpenAI 걸린 분류: <span className="font-mono">{log.categories.join(", ") || "없음"}</span>
                  </span>
                )}
              </p>
              {!log.bannedWordMatched && (
                <details className="mt-2">
                  <summary className="cursor-pointer text-sm text-slate-600">분류별 점수</summary>
                  <div className="mt-2">
                    <ScoreList scores={log.scores} flagged={log.categories} />
                  </div>
                </details>
              )}
            </li>
          ))}
        </ul>
      )}
      {list?.status === "loaded" && list.error !== null && <ErrorState error={list.error} />}
      {list?.status === "loaded" && list.nextCursor !== null && (
        <button
          type="button"
          onClick={() => void loadModerationLogs(uid, true)}
          disabled={list.loadingMore}
          className="mt-4 w-full rounded-md border border-slate-300 py-2 text-sm hover:bg-slate-100 disabled:opacity-50"
        >
          {list.loadingMore ? "불러오는 중…" : "더 보기"}
        </button>
      )}
    </div>
  );
}
