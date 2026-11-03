import type {AdminApiError} from "../services/adminApi";

// 로딩, 빈 데이터, 권한 없음, 다시 시도할 수 있는 오류를 구분해 보여준다(docs/dev_rules.md의 Admin 웹 UI).

export function Loading({text = "불러오는 중…"}: {text?: string}) {
  return (
    <p role="status" className="py-8 text-center text-sm text-slate-500">
      ⏳ {text}
    </p>
  );
}

export function Empty({text}: {text: string}) {
  return <p className="py-8 text-center text-sm text-slate-500">— {text}</p>;
}

/** 오류 종류에 맞는 문구. */
export function getErrorText(error: AdminApiError): string {
  switch (error.kind) {
    case "permission":
      return "🔒 권한이 없어요. 관리자 계정으로 다시 로그인해 주세요.";
    case "notFound":
      return "찾을 수 없어요. 지워졌거나 잘못된 주소예요.";
    case "alreadyResolved":
      return "이미 다른 관리자가 처리한 신고예요. 새로 고친 결과를 확인해 주세요.";
    case "invalid":
      return "입력을 서버가 받지 않았어요. 값을 확인해 주세요.";
    case "contract":
      return "서버 응답 모양이 예상과 달라요. Admin 웹과 Functions 버전을 확인해 주세요.";
    case "retryable":
      return "불러오지 못했어요. 잠시 후 다시 시도해 주세요.";
  }
}

export function ErrorState({error, onRetry}: {error: AdminApiError; onRetry?: () => void}) {
  const retryable = error.kind === "retryable" || error.kind === "contract";
  return (
    <div role="alert" className="my-4 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">
      <p>⚠ {getErrorText(error)}</p>
      {retryable && onRetry !== undefined && (
        <button
          type="button"
          onClick={onRetry}
          className="mt-2 rounded-md border border-red-300 bg-white px-3 py-1 font-medium hover:bg-red-100"
        >
          다시 시도
        </button>
      )}
    </div>
  );
}
