import {useCallback, useEffect} from "react";
import {Link, useParams} from "react-router";
import {SanctionForm} from "../components/SanctionForm";
import {RestoreAccountSection} from "../components/RestoreAccountSection";
import {ErrorState, Loading} from "../components/States";
import {UserHistoryPanel} from "../components/UserHistoryPanel";
import type {ResolveReportInput} from "../models/admin";
import {useModerationStore} from "../stores/moderationStore";

/** 사용자 기록과 신고 없이 제재 걸기. uid는 URL이 정한다. */
export function UserPage() {
  const {uid = ""} = useParams<{uid: string}>();
  const resource = useModerationStore((state) => state.users[uid]);
  const submitting = useModerationStore((state) => state.submitting);
  const loadUser = useModerationStore((state) => state.loadUser);
  const sanctionUser = useModerationStore((state) => state.sanctionUser);

  const reload = useCallback(() => void loadUser(uid), [loadUser, uid]);
  const submit = useCallback(
    async (input: ResolveReportInput) => {
      // 신고가 없으므로 무혐의는 고를 수 없다(SanctionForm이 보여주지 않는다).
      if (input.action === "dismissed") {
        return;
      }
      await sanctionUser(uid, {type: input.action, durationDays: input.durationDays, reason: input.reason});
    },
    [sanctionUser, uid],
  );

  useEffect(() => {
    reload();
  }, [reload]);

  return (
    <div>
      <Link to="/users" className="text-sm text-blue-700 underline">
        ← 사용자 찾기
      </Link>
      {(resource === undefined || resource.status === "loading") && <Loading />}
      {resource?.status === "error" && <ErrorState error={resource.error} onRetry={reload} />}
      {resource?.status === "loaded" && (
        <div className="mt-4 space-y-4">
          {resource.data.profile?.deletedAt != null && (
            <RestoreAccountSection
              key={uid}
              uid={uid}
              nickname={resource.data.profile.nickname}
              deletedAt={resource.data.profile.deletedAt}
            />
          )}
          <div className="grid gap-4 lg:grid-cols-[2fr_3fr]">
            <SanctionForm
              key={uid}
              targetUid={uid}
              targetNickname={resource.data.profile?.nickname ?? null}
              currentSanction={resource.data.sanction}
              sanctions={resource.data.sanctions}
              reportId={null}
              submitting={submitting}
              onSubmit={submit}
            />
            <UserHistoryPanel user={resource.data} />
          </div>
        </div>
      )}
    </div>
  );
}
