import {useState} from "react";
import {REASON_MAX_LENGTH} from "../config";
import {AdminApiError} from "../services/adminApi";
import {useModerationStore} from "../stores/moderationStore";
import {formatDateTime} from "../utils/format";
import {ConfirmDialog} from "./ConfirmDialog";
import {getErrorText} from "./States";

interface RestoreAccountSectionProps {
  uid: string;
  nickname: string;
  deletedAt: number;
}

/** 탈퇴한 사용자의 표시와 탈퇴 되돌리기. 30일이 지나면 실제로 지워져 프로필이 없어지므로 이 칸도 없어진다. */
export function RestoreAccountSection({uid, nickname, deletedAt}: RestoreAccountSectionProps) {
  const submitting = useModerationStore((state) => state.submitting);
  const restoreAccount = useModerationStore((state) => state.restoreAccount);
  const [reason, setReason] = useState("");
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const trimmedReason = reason.trim();

  async function submit(): Promise<void> {
    try {
      setError(null);
      await restoreAccount(uid, trimmedReason);
    } catch (restoreError) {
      setConfirming(false);
      setError(restoreError instanceof AdminApiError ? getErrorText(restoreError) : "되돌리지 못했어요.");
    }
  }

  return (
    <section className="rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm">
      <h2 className="font-bold">⚠ 탈퇴함 · {formatDateTime(deletedAt)}</h2>
      <p className="mt-1 text-slate-700">30일이 지나면 예약 작업이 지워요. 그 전에는 되돌릴 수 있어요.</p>
      <label className="mt-3 block">
        <span className="font-medium">사유</span>
        <textarea
          value={reason}
          maxLength={REASON_MAX_LENGTH}
          onChange={(event) => setReason(event.target.value)}
          rows={2}
          className="mt-1 w-full rounded-md border border-slate-300 bg-white px-2 py-1"
        />
      </label>
      {error !== null && (
        <p role="alert" className="mt-2 text-red-700">
          ⚠ {error}
        </p>
      )}
      <button
        type="button"
        onClick={() => setConfirming(true)}
        disabled={trimmedReason === "" || submitting}
        className="mt-2 rounded-md bg-slate-900 px-4 py-2 font-semibold text-white disabled:opacity-40"
      >
        검토하기
      </button>
      {confirming && (
        <ConfirmDialog
          title="탈퇴를 되돌릴까요?"
          confirmLabel="되돌리기"
          busy={submitting}
          onConfirm={() => void submit()}
          onCancel={() => setConfirming(false)}
        >
          <p>
            대상: <strong>{nickname}</strong> <span className="font-mono text-xs">{uid}</span>
          </p>
          <p>사유: {trimmedReason}</p>
          <p className="text-slate-500">사용자는 같은 계정으로 다시 로그인할 수 있어요.</p>
        </ConfirmDialog>
      )}
    </section>
  );
}
