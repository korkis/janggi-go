import {type ReactNode, useEffect, useRef} from "react";

interface ConfirmDialogProps {
  title: string;
  children: ReactNode;
  confirmLabel: string;
  // 요청 중이다. 버튼을 막아 중복 제출을 막는다.
  busy: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/** 실행 직전 확인 창. 브라우저 기본 `<dialog>`로 띄워 포커스와 Esc 닫기를 맡긴다. */
export function ConfirmDialog({title, children, confirmLabel, busy, onConfirm, onCancel}: ConfirmDialogProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    dialog?.showModal();
    return () => dialog?.close();
  }, []);

  return (
    <dialog
      ref={dialogRef}
      onCancel={(event) => {
        event.preventDefault();
        if (!busy) {
          onCancel();
        }
      }}
      className="m-auto w-full max-w-lg rounded-xl p-0 shadow-xl backdrop:bg-black/40"
    >
      <div className="p-6">
        <h2 className="text-lg font-bold">{title}</h2>
        <div className="mt-4 space-y-2 text-sm">{children}</div>
        <div className="mt-6 flex justify-end gap-2">
          <button
            type="button"
            onClick={onCancel}
            disabled={busy}
            className="rounded-md border border-slate-300 px-4 py-2 text-sm hover:bg-slate-100 disabled:opacity-50"
          >
            취소
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={busy}
            className="rounded-md bg-red-700 px-4 py-2 text-sm font-semibold text-white hover:bg-red-800 disabled:opacity-50"
          >
            {busy ? "보내는 중…" : confirmLabel}
          </button>
        </div>
      </div>
    </dialog>
  );
}
