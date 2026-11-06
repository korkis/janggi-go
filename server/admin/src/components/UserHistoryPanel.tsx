import {Link} from "react-router";
import type {UserHistoryView} from "../models/admin";
import {CHANNEL_LABELS, formatDateTime, formatRank, formatSanctionEnd} from "../utils/format";
import {ActionBadge, ReportStatusBadge, SanctionBadge} from "./Badges";
import {Empty} from "./States";

/** 사용자의 프로필, 지금 걸린 제재, 제재 이력, 신고된 기록, 검사 기록, 닉네임 변경. 신고 상세와 사용자 조회가 함께 쓴다. */
export function UserHistoryPanel({user}: {user: UserHistoryView}) {
  const now = Date.now();
  const {profile, sanction} = user;
  return (
    <div className="space-y-4">
      <section className="rounded-xl border border-slate-200 bg-white p-4">
        <h2 className="font-bold">
          <Link to={`/users/${encodeURIComponent(user.uid)}`} className="hover:underline">
            {profile?.nickname ?? "(프로필 없음)"}
          </Link>
        </h2>
        <p className="font-mono text-xs text-slate-500">{user.uid}</p>
        {profile !== null && (
          <p className="mt-1 text-sm text-slate-700">
            {formatRank(profile.rankLevel)} · {profile.stats.games}판 {profile.stats.wins}승 {profile.stats.losses}패 ·
            가입 {formatDateTime(profile.createdAt)}
          </p>
        )}
        {profile?.deletedAt != null && <p className="mt-1 text-sm">⚠ 탈퇴함 · {formatDateTime(profile.deletedAt)}</p>}
        {profile === null && <p className="mt-1 text-sm text-slate-700">프로필이 없어요. 탈퇴해 지웠을 수 있어요.</p>}
        <div className="mt-3 text-sm">
          지금 제재:{" "}
          {sanction === null ? (
            <span className="text-slate-600">○ 없음</span>
          ) : (
            <span>
              <SanctionBadge type={sanction.type} /> {formatSanctionEnd(sanction.type, sanction.endsAt, now)} · 사유 “
              {sanction.reason}”
            </span>
          )}
        </div>
      </section>

      <section className="rounded-xl border border-slate-200 bg-white p-4">
        <h3 className="font-semibold">제재 이력 ({user.sanctions.length})</h3>
        {user.sanctions.length === 0 ? (
          <Empty text="제재 이력이 없어요" />
        ) : (
          <ul className="mt-2 divide-y divide-slate-100 text-sm">
            {user.sanctions.map((item) => (
              <li key={item.sanctionId} className="py-2">
                <SanctionBadge type={item.type} /> {formatDateTime(item.startsAt)}
                {item.endsAt !== null && ` ~ ${formatDateTime(item.endsAt)}`} · “{item.reason}”
                {item.reportId !== null && (
                  <Link to={`/reports/${encodeURIComponent(item.reportId)}`} className="ml-2 text-blue-700 underline">
                    신고 보기
                  </Link>
                )}
                {item.adminUid === null && <span className="ml-2 text-xs text-slate-500">(자동)</span>}
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="rounded-xl border border-slate-200 bg-white p-4">
        <h3 className="font-semibold">신고된 기록 ({user.reports.length})</h3>
        {user.reports.length === 0 ? (
          <Empty text="신고된 기록이 없어요" />
        ) : (
          <ul className="mt-2 divide-y divide-slate-100 text-sm">
            {user.reports.map((item) => (
              <li key={item.reportId} className="flex flex-wrap items-center gap-2 py-2">
                <ReportStatusBadge status={item.status} />
                {item.action !== null && <ActionBadge action={item.action} />}
                <Link
                  to={`/reports/${encodeURIComponent(item.reportId)}`}
                  className="min-w-0 flex-1 truncate hover:underline"
                >
                  “{item.messageText}”
                </Link>
                <span className="text-xs text-slate-500">
                  {item.reporterNickname ?? item.reporterUid} 신고 · {formatDateTime(item.createdAt)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="rounded-xl border border-slate-200 bg-white p-4">
        <h3 className="font-semibold">
          검사에 걸린 메시지 ({user.moderationLogs.length}){" "}
          <Link
            to={`/moderation-logs?uid=${encodeURIComponent(user.uid)}`}
            className="text-sm font-normal text-blue-700 underline"
          >
            모두 보기
          </Link>
        </h3>
        {user.moderationLogs.length === 0 ? (
          <Empty text="검사 기록이 없어요" />
        ) : (
          <ul className="mt-2 divide-y divide-slate-100 text-sm">
            {user.moderationLogs.map((log) => (
              <li key={log.logId} className="py-2">
                <span className="text-xs text-slate-500">
                  {formatDateTime(log.createdAt)} · {CHANNEL_LABELS[log.channel]} ·{" "}
                  {log.bannedWordMatched ? "금칙어" : log.categories.join(", ")}
                </span>
                <p>“{log.text}”</p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="rounded-xl border border-slate-200 bg-white p-4">
        <h3 className="font-semibold">닉네임 변경 ({user.nicknameChanges.length})</h3>
        {user.nicknameChanges.length === 0 ? (
          <Empty text="바꾼 적이 없어요" />
        ) : (
          <ul className="mt-2 text-sm">
            {user.nicknameChanges.map((change) => (
              <li key={change.changedAt}>
                {change.before} → {change.after}{" "}
                <span className="text-xs text-slate-500">{formatDateTime(change.changedAt)}</span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
