import {useCallback, useEffect} from "react";
import {Link, useParams} from "react-router";
import {ActionBadge, ReportStatusBadge} from "../components/Badges";
import {SanctionForm} from "../components/SanctionForm";
import {ScoreList} from "../components/ScoreList";
import {ErrorState, Loading} from "../components/States";
import {UserHistoryPanel} from "../components/UserHistoryPanel";
import type {ReportDetailView, ReportMessageView, ResolveReportInput} from "../models/admin";
import {useModerationStore} from "../stores/moderationStore";
import {CHANNEL_LABELS, formatDateTime} from "../utils/format";

/** 신고 상세. 신고된 메시지와 앞뒤 대화, 검사 결과, 피신고자의 지난 기록, 처리 입력을 함께 보여준다. 신고 ID는 URL이 정한다. */
export function ReportDetailPage() {
  const {reportId = ""} = useParams<{reportId: string}>();
  const resource = useModerationStore((state) => state.reportDetails[reportId]);
  const submitting = useModerationStore((state) => state.submitting);
  const loadReport = useModerationStore((state) => state.loadReport);
  const resolveReport = useModerationStore((state) => state.resolveReport);

  const reload = useCallback(() => void loadReport(reportId), [loadReport, reportId]);
  const submit = useCallback((input: ResolveReportInput) => resolveReport(reportId, input), [resolveReport, reportId]);

  useEffect(() => {
    reload();
  }, [reload]);

  return (
    <div>
      <Link to="/reports" className="text-sm text-blue-700 underline">
        ← 신고 목록
      </Link>
      {(resource === undefined || resource.status === "loading") && <Loading />}
      {resource?.status === "error" && <ErrorState error={resource.error} onRetry={reload} />}
      {resource?.status === "loaded" && (
        <div className="mt-4 grid gap-4 lg:grid-cols-[3fr_2fr]">
          <div className="space-y-4">
            <ReportSection report={resource.data.report} />
            {resource.data.report.status === "pending" ? (
              <SanctionForm
                key={reportId}
                targetUid={resource.data.target.uid}
                targetNickname={resource.data.target.profile?.nickname ?? null}
                currentSanction={resource.data.target.sanction}
                sanctions={resource.data.target.sanctions}
                reportId={reportId}
                submitting={submitting}
                onSubmit={submit}
                onAlreadyResolved={reload}
              />
            ) : (
              <ResolutionSection report={resource.data.report} />
            )}
          </div>
          <UserHistoryPanel user={resource.data.target} />
        </div>
      )}
    </div>
  );
}

function ReportSection({report}: {report: ReportDetailView}) {
  const conversation = [...report.context, report.message].sort((a, b) => a.sentAt - b.sentAt);
  return (
    <section className="rounded-xl border border-slate-200 bg-white p-4">
      <div className="flex flex-wrap items-center gap-2">
        <ReportStatusBadge status={report.status} />
        <span className="text-sm">{CHANNEL_LABELS[report.channel]}</span>
        {report.gameId !== null && <span className="font-mono text-xs text-slate-500">대국 {report.gameId}</span>}
        <span className="ml-auto text-xs text-slate-500">신고 {formatDateTime(report.createdAt)}</span>
      </div>
      <p className="mt-2 text-sm">
        <Link to={`/users/${encodeURIComponent(report.reporterUid)}`} className="underline">
          {report.reporterNickname ?? report.reporterUid}
        </Link>
        님이{" "}
        <Link to={`/users/${encodeURIComponent(report.targetUid)}`} className="font-semibold underline">
          {report.targetNickname ?? report.targetUid}
        </Link>
        님의 메시지를 신고했어요.
      </p>

      <h3 className="mt-4 text-sm font-semibold">대화 (앞뒤 각 5개)</h3>
      <ol className="mt-2 space-y-1">
        {conversation.map((message) => (
          <MessageRow
            key={message.messageId}
            message={message}
            reported={message.messageId === report.message.messageId}
          />
        ))}
      </ol>

      <h3 className="mt-4 text-sm font-semibold">신고된 메시지의 검사 결과</h3>
      {report.check === null ? (
        <p className="text-sm text-slate-500">— 검사 결과가 지워졌어요(채팅 보관 기간 90일).</p>
      ) : (
        <div className="mt-2">
          <p className="mb-2 text-sm">
            금칙어: {report.check.bannedWordMatched ? "● 걸림" : "○ 안 걸림"} (통과한 메시지)
          </p>
          <ScoreList scores={report.check.scores} />
        </div>
      )}
    </section>
  );
}

function MessageRow({message, reported}: {message: ReportMessageView; reported: boolean}) {
  return (
    <li
      className={`rounded-md px-2 py-1 text-sm ${reported ? "border-l-4 border-red-500 bg-red-50 font-medium" : "bg-slate-50"}`}
    >
      {reported && <span className="mr-1 text-xs text-red-700">[신고됨]</span>}
      <span className="text-slate-600">{message.nickname}</span>
      <span className="mx-1 text-xs text-slate-400">{formatDateTime(message.sentAt)}</span>
      <span className="whitespace-pre-wrap">{message.text}</span>
    </li>
  );
}

function ResolutionSection({report}: {report: ReportDetailView}) {
  const resolution = report.resolution;
  if (resolution === null) {
    return null;
  }
  return (
    <section className="rounded-xl border border-slate-200 bg-white p-4 text-sm">
      <h2 className="font-bold">처리 결과</h2>
      <p className="mt-2">
        <ActionBadge action={resolution.action} />
        {report.resolvedAt !== null && <span className="ml-2 text-slate-500">{formatDateTime(report.resolvedAt)}</span>}
      </p>
      <p className="mt-2 whitespace-pre-wrap">사유: {resolution.reason}</p>
      <p className="mt-1 font-mono text-xs text-slate-500">처리한 관리자 {resolution.adminUid}</p>
    </section>
  );
}
