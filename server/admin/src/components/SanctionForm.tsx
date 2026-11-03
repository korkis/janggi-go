import {useState} from "react";
import {REASON_MAX_LENGTH, SANCTION_DURATION_DAYS} from "../config";
import type {ActiveSanctionView, ReportAction, ResolveReportInput, SanctionView} from "../models/admin";
import {AdminApiError} from "../services/adminApi";
import {useUiStore} from "../stores/uiStore";
import {ACTION_LABELS, formatDuration, formatSanctionEnd} from "../utils/format";
import {getNextSanctionStep, isTimedSanction} from "../utils/sanctionSteps";
import {ActionBadge, SanctionBadge} from "./Badges";
import {ConfirmDialog} from "./ConfirmDialog";
import {getErrorText} from "./States";

interface SanctionFormProps {
  targetUid: string;
  targetNickname: string | null;
  // 지금 걸린 제재와 지난 제재. 다음 단계 제안과 확인 창에 쓴다.
  currentSanction: ActiveSanctionView | null;
  sanctions: SanctionView[];
  // 신고를 처리하는 중이면 그 신고. 무혐의를 고를 수 있다.
  reportId: string | null;
  submitting: boolean;
  /** 조치를 보낸다. 실패하면 AdminApiError를 던진다. */
  onSubmit: (input: ResolveReportInput) => Promise<void>;
  /** 이미 처리한 신고라 거절됐을 때. 상세를 다시 읽는다. */
  onAlreadyResolved?: () => void;
}

const STEP_LABELS = ["경고", "1일", "7일", "30일", "영구 정지"];

/**
 * 신고 처리와 사용자 제재 입력. 조치, 기간, 사유를 고르고 "검토하기"를 누르면 대상, 종류, 기간, 연결된 신고를 다시 보여주는 확인
 * 창을 띄운다(docs/dev_rules.md의 Admin 웹 UI). 다음 제재 단계를 처음 값으로 제안한다.
 */
export function SanctionForm(props: SanctionFormProps) {
  const {targetUid, targetNickname, currentSanction, sanctions, reportId, submitting} = props;
  const showNotice = useUiStore((state) => state.showNotice);
  const next = getNextSanctionStep(sanctions);
  const [action, setAction] = useState<ReportAction>(next.choice.type);
  const [durationDays, setDurationDays] = useState<number | null>(next.choice.durationDays);
  const [reason, setReason] = useState("");
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const actions: ReportAction[] =
    reportId === null
      ? ["warning", "chatRestriction", "suspension", "permanentBan"]
      : ["dismissed", "warning", "chatRestriction", "suspension", "permanentBan"];
  const timed = action !== "dismissed" && isTimedSanction(action);
  const trimmedReason = reason.trim();
  const reasonValid = trimmedReason.length > 0 && trimmedReason.length <= REASON_MAX_LENGTH;
  const now = Date.now();
  const currentBlocking =
    currentSanction !== null &&
    currentSanction.type !== "warning" &&
    (currentSanction.endsAt === null || currentSanction.endsAt > now);

  function selectAction(value: ReportAction): void {
    setAction(value);
    if (value !== "dismissed" && isTimedSanction(value)) {
      setDurationDays((days) => days ?? SANCTION_DURATION_DAYS[0]!);
    } else {
      setDurationDays(null);
    }
  }

  function applySuggestion(): void {
    selectAction(next.choice.type);
    setDurationDays(next.choice.durationDays);
  }

  function getDurationText(): string {
    if (timed) {
      return formatDuration(durationDays) ?? "";
    }
    return action === "permanentBan" ? "영구" : "없음";
  }

  function openConfirm(): void {
    setError(null);
    if (reasonValid) {
      setConfirming(true);
    }
  }

  async function submit(): Promise<void> {
    try {
      await props.onSubmit({action, durationDays: timed ? durationDays : null, reason: trimmedReason});
      setConfirming(false);
      setReason("");
      showNotice({kind: "success", text: `${targetNickname ?? targetUid}: ${ACTION_LABELS[action]} 처리했어요.`});
    } catch (submitError) {
      setConfirming(false);
      if (submitError instanceof AdminApiError) {
        setError(getErrorText(submitError));
        if (submitError.kind === "alreadyResolved") {
          props.onAlreadyResolved?.();
        }
      } else {
        console.error("조치 실패", {name: (submitError as Error).name});
        setError("조치하지 못했어요. 잠시 후 다시 시도해 주세요.");
      }
    }
  }

  return (
    <section className="rounded-xl border border-slate-200 bg-white p-4">
      <h2 className="font-bold">{reportId === null ? "제재 걸기" : "신고 처리"}</h2>
      <p className="mt-1 text-sm text-slate-600">
        제안 단계: <strong>{STEP_LABELS[next.step]}</strong> (지난 제재 {sanctions.length}번) · 단계: 경고 → 1일 → 7일 →
        30일 → 영구 정지{" "}
        <button type="button" onClick={applySuggestion} className="ml-1 text-blue-700 underline">
          제안대로 고르기
        </button>
      </p>

      <fieldset className="mt-4">
        <legend className="text-sm font-medium">조치</legend>
        <div className="mt-2 flex flex-wrap gap-2">
          {actions.map((value) => (
            <label
              key={value}
              className={`cursor-pointer rounded-md border px-3 py-1.5 text-sm ${
                action === value ? "border-slate-900 bg-slate-900 text-white" : "border-slate-300 bg-white"
              }`}
            >
              <input
                type="radio"
                name="action"
                value={value}
                checked={action === value}
                onChange={() => selectAction(value)}
                className="sr-only"
              />
              {ACTION_LABELS[value]}
            </label>
          ))}
        </div>
      </fieldset>

      {timed && (
        <fieldset className="mt-4">
          <legend className="text-sm font-medium">기간</legend>
          <div className="mt-2 flex gap-2">
            {SANCTION_DURATION_DAYS.map((days) => (
              <label
                key={days}
                className={`cursor-pointer rounded-md border px-3 py-1.5 text-sm ${
                  durationDays === days ? "border-slate-900 bg-slate-900 text-white" : "border-slate-300 bg-white"
                }`}
              >
                <input
                  type="radio"
                  name="durationDays"
                  value={days}
                  checked={durationDays === days}
                  onChange={() => setDurationDays(days)}
                  className="sr-only"
                />
                {days}일
              </label>
            ))}
          </div>
        </fieldset>
      )}

      <label className="mt-4 block text-sm font-medium">
        사유{" "}
        {action !== "dismissed" && (
          <span className="font-normal text-slate-500">(제재 팝업으로 사용자에게 보여요)</span>
        )}
        <textarea
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          maxLength={REASON_MAX_LENGTH}
          rows={3}
          className="mt-1 block w-full rounded-md border border-slate-300 p-2 font-normal"
          placeholder={action === "dismissed" ? "예: 장기 용어라 문제없음" : "예: 상대에게 욕설"}
        />
        <span className="text-xs font-normal text-slate-500">
          {trimmedReason.length}/{REASON_MAX_LENGTH}
        </span>
      </label>

      {error !== null && (
        <p role="alert" className="mt-2 text-sm text-red-700">
          ⚠ {error}
        </p>
      )}

      <button
        type="button"
        onClick={openConfirm}
        disabled={!reasonValid || submitting}
        className="mt-4 rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-40"
      >
        검토하기
      </button>
      {!reasonValid && <span className="ml-2 text-xs text-slate-500">사유를 적어야 해요.</span>}

      {confirming && (
        <ConfirmDialog
          title="이대로 조치할까요?"
          confirmLabel="조치하기"
          busy={submitting}
          onConfirm={() => void submit()}
          onCancel={() => setConfirming(false)}
        >
          <dl className="grid grid-cols-[6rem_1fr] gap-y-2">
            <dt className="text-slate-500">대상</dt>
            <dd>
              {targetNickname ?? "(프로필 없음)"} <span className="font-mono text-xs text-slate-500">{targetUid}</span>
            </dd>
            <dt className="text-slate-500">조치</dt>
            <dd>
              <ActionBadge action={action} />
            </dd>
            <dt className="text-slate-500">기간</dt>
            <dd>{getDurationText()}</dd>
            <dt className="text-slate-500">연결된 신고</dt>
            <dd className="font-mono text-xs break-all">{reportId ?? "없음"}</dd>
            <dt className="text-slate-500">사유</dt>
            <dd className="whitespace-pre-wrap">{trimmedReason}</dd>
          </dl>
          {currentSanction !== null && action !== "dismissed" && (
            <p className="rounded-md bg-amber-50 p-2 text-amber-900">
              지금 걸린 제재: <SanctionBadge type={currentSanction.type} />{" "}
              {formatSanctionEnd(currentSanction.type, currentSanction.endsAt, now)}.{" "}
              {action === "warning" && currentBlocking
                ? "경고는 이 제재를 풀지 않고 기록에만 남아요."
                : "새 제재가 이 제재를 대신해요."}
            </p>
          )}
          {reportId !== null && <p className="text-slate-500">같은 메시지에 대한 다른 처리 전 신고도 함께 닫혀요.</p>}
        </ConfirmDialog>
      )}
    </section>
  );
}
