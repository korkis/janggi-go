import {useEffect, useState} from "react";
import {ConfirmDialog} from "../components/ConfirmDialog";
import {ErrorState, Loading, getErrorText} from "../components/States";
import {APP_CONFIG_LIMITS, APP_VERSION_PATTERN, SERVICE_NOTICE_MAX_LENGTH} from "../config";
import type {AppConfig} from "../models/admin";
import {AdminApiError} from "../services/adminApi";
import {useConfigStore} from "../stores/configStore";
import {useUiStore} from "../stores/uiStore";

type NumberField = keyof typeof APP_CONFIG_LIMITS;
type BooleanField =
  | "onlineUsersVisible"
  | "autoSanctionEnabled"
  | "entryFeeEnabled"
  | "timeExtensionEnabled"
  | "gamePracticeEnabled"
  | "chatEnabled"
  | "signupEnabled"
  | "webEnabled"
  | "coinSaleEnabled";

interface NumberFieldInfo {
  key: NumberField;
  label: string;
  unit: string;
  help?: string;
}

const NUMBER_FIELDS: NumberFieldInfo[] = [
  {
    key: "disconnectLimitSeconds",
    label: "접속 끊김 허용 시간",
    unit: "초",
    help: "한 대국에서 끊겨 있어도 되는 시간 합계. 새로 만드는 대국부터 적용돼요.",
  },
  {
    key: "quickRematchLimit",
    label: "빠른 대국 다시 두기 횟수",
    unit: "번",
    help: "빠른 대국에서 같은 상대와 연달아 다시 둘 수 있는 횟수.",
  },
  {
    key: "heartbeatSeconds",
    label: "접속 확인 주기",
    unit: "초",
    help: "대국 중 앱이 살아 있음을 알리는 주기. 대국 서버는 15초 동안 소식이 없으면 끊긴 것으로 봐요.",
  },
];

const COIN_FIELDS: NumberFieldInfo[] = [
  {key: "coinSignupBonus", label: "가입", unit: "엽전"},
  {key: "coinEntryFee", label: "대국 참가비", unit: "엽전"},
  {key: "coinWinReward", label: "대국 보상: 승", unit: "엽전"},
  {key: "coinLossReward", label: "대국 보상: 패", unit: "엽전"},
  {key: "coinAttendanceReward", label: "출석", unit: "엽전"},
  {key: "coinAttendanceStreakReward", label: "출석: 연속 7일째", unit: "엽전", help: "평소 출석 값 대신 줘요."},
  {key: "coinNicknameChangeCost", label: "닉네임 변경", unit: "엽전", help: "두 번째 변경부터 받아요."},
  {key: "coinTimeExtensionCost", label: "시간 연장 1회", unit: "엽전"},
  {key: "coinGamePracticeCost", label: "대국 중 놓아보기 한 판", unit: "엽전"},
];

const BOOLEAN_FIELDS: {key: BooleanField; label: string; help: string}[] = [
  {
    key: "chatEnabled",
    label: "채팅",
    help: "끄면 앱에서 채팅이 사라지고 서버가 새 메시지를 거절해요. 신고는 받아요.",
  },
  {
    key: "signupEnabled",
    label: "새 가입",
    help: "끄면 새로 가입할 수 없어요. 기존 사용자는 그대로예요.",
  },
  {
    key: "webEnabled",
    label: "웹",
    help: "끄면 웹은 안내 화면만 보여주고 서버가 웹의 호출을 거절해요. 진행 중인 웹 대국은 끊김패나 시간패가 돼요.",
  },
  {
    key: "coinSaleEnabled",
    label: "엽전 충전 판매",
    help: "끄면 다음에 켜는 앱의 상점에서 충전 상품이 사라져요. 켜져 있는 앱은 다시 켤 때까지 살 수 있고, 결제가 끝난 충전은 지급해요.",
  },
  {
    key: "onlineUsersVisible",
    label: "접속자 목록 보이기",
    help: "대국실 접속자 탭과 방 대기실의 접속자 초대하기를 보여줘요.",
  },
  {
    key: "autoSanctionEnabled",
    label: "자동 제재",
    help: "자동 제재 기준은 아직 정하지 않아 켜도 아무 일도 하지 않아요.",
  },
  {
    key: "entryFeeEnabled",
    label: "대국 참가비 받기",
    help: "끄면 새 대국부터 참가비를 받지 않아요. 대국 보상은 그대로예요.",
  },
  {
    key: "timeExtensionEnabled",
    label: "시간 연장",
    help: "끄면 앱에서 버튼이 사라지고 서버가 새 연장을 거절해요.",
  },
  {
    key: "gamePracticeEnabled",
    label: "대국 중 놓아보기",
    help: "끄면 앱에서 버튼이 사라지고 서버가 새 결제를 거절해요.",
  },
];

/** 폼에 입력 중인 숫자. 비우거나 잘못 적은 값도 그대로 두고 저장 전에 확인한다. */
type Draft = Record<NumberField, string> &
  Record<BooleanField, boolean> & {
    minAppVersion: string;
    noticeEnabled: boolean;
    noticeMessageKo: string;
    noticeMessageEn: string;
    noticeGamesBlocked: boolean;
  };

function toDraft(config: AppConfig): Draft {
  const numbers = Object.fromEntries(
    [...NUMBER_FIELDS, ...COIN_FIELDS].map(({key}) => [key, String(config[key])]),
  ) as Record<NumberField, string>;
  return {
    ...numbers,
    onlineUsersVisible: config.onlineUsersVisible,
    autoSanctionEnabled: config.autoSanctionEnabled,
    entryFeeEnabled: config.entryFeeEnabled,
    timeExtensionEnabled: config.timeExtensionEnabled,
    gamePracticeEnabled: config.gamePracticeEnabled,
    chatEnabled: config.chatEnabled,
    signupEnabled: config.signupEnabled,
    webEnabled: config.webEnabled,
    coinSaleEnabled: config.coinSaleEnabled,
    minAppVersion: config.minAppVersion,
    noticeEnabled: config.serviceNotice !== null,
    noticeMessageKo: config.serviceNotice?.messageKo ?? "",
    noticeMessageEn: config.serviceNotice?.messageEn ?? "",
    noticeGamesBlocked: config.serviceNotice?.gamesBlocked ?? false,
  };
}

function isNoticeMessageValid(message: string): boolean {
  return message.trim() !== "" && message.length <= SERVICE_NOTICE_MAX_LENGTH;
}

function isNoticeValid(draft: Draft): boolean {
  return (
    !draft.noticeEnabled || (isNoticeMessageValid(draft.noticeMessageKo) && isNoticeMessageValid(draft.noticeMessageEn))
  );
}

/** 범위 안의 정수면 그 값, 아니면 null. */
function parseField(draft: Draft, key: NumberField): number | null {
  const value = Number(draft[key]);
  const {min, max} = APP_CONFIG_LIMITS[key];
  return draft[key].trim() !== "" && Number.isInteger(value) && value >= min && value <= max ? value : null;
}

function toConfig(draft: Draft): AppConfig | null {
  const numbers = {} as Record<NumberField, number>;
  for (const {key} of [...NUMBER_FIELDS, ...COIN_FIELDS]) {
    const value = parseField(draft, key);
    if (value === null) {
      return null;
    }
    numbers[key] = value;
  }
  if (!APP_VERSION_PATTERN.test(draft.minAppVersion) || !isNoticeValid(draft)) {
    return null;
  }
  return {
    ...numbers,
    onlineUsersVisible: draft.onlineUsersVisible,
    autoSanctionEnabled: draft.autoSanctionEnabled,
    entryFeeEnabled: draft.entryFeeEnabled,
    timeExtensionEnabled: draft.timeExtensionEnabled,
    gamePracticeEnabled: draft.gamePracticeEnabled,
    chatEnabled: draft.chatEnabled,
    signupEnabled: draft.signupEnabled,
    webEnabled: draft.webEnabled,
    coinSaleEnabled: draft.coinSaleEnabled,
    minAppVersion: draft.minAppVersion,
    serviceNotice: draft.noticeEnabled
      ? {
          messageKo: draft.noticeMessageKo,
          messageEn: draft.noticeMessageEn,
          gamesBlocked: draft.noticeGamesBlocked,
        }
      : null,
  };
}

function formatValue(config: AppConfig, key: keyof AppConfig): string {
  const value = config[key];
  if (typeof value === "boolean") {
    return value ? "● 켬" : "○ 끔";
  }
  if (value === null) {
    return "없음";
  }
  if (typeof value === "object") {
    return `“${value.messageKo}” / “${value.messageEn}” · 새 대국 ${value.gamesBlocked ? "막음" : "받음"}`;
  }
  return String(value);
}

function isSameValue(a: AppConfig[keyof AppConfig], b: AppConfig[keyof AppConfig]): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

/** Firestore `configs/app` 바꾸기. 바뀌는 값을 확인 창에서 다시 보여주고 저장한다. */
export function ConfigPage() {
  const resource = useConfigStore((state) => state.config);
  const saving = useConfigStore((state) => state.saving);
  const load = useConfigStore((state) => state.load);
  const save = useConfigStore((state) => state.save);
  const showNotice = useUiStore((state) => state.showNotice);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void load();
  }, [load]);

  const serverConfig = resource?.status === "loaded" ? resource.data : null;
  // 서버 값을 처음 받거나 저장해 바뀌면 입력을 서버 값으로 맞춘다.
  const [draftSource, setDraftSource] = useState<AppConfig | null>(null);
  if (serverConfig !== null && serverConfig !== draftSource) {
    setDraftSource(serverConfig);
    setDraft(toDraft(serverConfig));
  }

  if (resource === null || resource.status === "loading") {
    return <Loading />;
  }
  if (resource.status === "error") {
    return <ErrorState error={resource.error} onRetry={() => void load()} />;
  }
  if (draft === null || serverConfig === null) {
    return <Loading />;
  }

  const nextConfig = toConfig(draft);
  const changedKeys =
    nextConfig === null
      ? []
      : (Object.keys(serverConfig) as (keyof AppConfig)[]).filter(
          (key) => !isSameValue(serverConfig[key], nextConfig[key]),
        );

  async function submit(config: AppConfig): Promise<void> {
    try {
      setError(null);
      await save(config);
      setConfirming(false);
      showNotice({kind: "success", text: "설정을 바꿨어요. 서버는 1분 안에 새 값을 써요."});
    } catch (saveError) {
      setConfirming(false);
      setError(saveError instanceof AdminApiError ? getErrorText(saveError) : "저장하지 못했어요.");
    }
  }

  function renderNumberField(field: NumberFieldInfo) {
    if (draft === null) {
      return null;
    }
    const {min, max} = APP_CONFIG_LIMITS[field.key];
    const invalid = parseField(draft, field.key) === null;
    return (
      <label key={field.key} className="block text-sm">
        <span className="font-medium">{field.label}</span>{" "}
        <span className="font-mono text-xs text-slate-500">{field.key}</span>
        <span className="mt-1 flex items-center gap-2">
          <input
            type="number"
            min={min}
            max={max}
            step={1}
            value={draft[field.key]}
            onChange={(event) => setDraft({...draft, [field.key]: event.target.value})}
            aria-invalid={invalid}
            className={`w-28 rounded-md border px-2 py-1 ${invalid ? "border-red-500" : "border-slate-300"}`}
          />
          {field.unit} ({min}~{max})
        </span>
        {field.help !== undefined && <span className="mt-1 block text-xs text-slate-500">{field.help}</span>}
        {invalid && (
          <span className="block text-xs text-red-700">
            ⚠ {min}~{max} 사이의 정수를 적어 주세요.
          </span>
        )}
      </label>
    );
  }

  return (
    <div className="max-w-2xl">
      <h1 className="text-xl font-bold">설정</h1>
      <p className="mt-1 text-sm text-slate-600">
        Firestore <code>configs/app</code>. 앱, Functions, 대국 서버가 함께 읽어요.
      </p>
      <div className="mt-4 space-y-4 rounded-xl border border-slate-200 bg-white p-4">
        {NUMBER_FIELDS.map(renderNumberField)}
        {BOOLEAN_FIELDS.map((field) => (
          <label key={field.key} className="flex items-start gap-2 text-sm">
            <input
              type="checkbox"
              checked={draft[field.key]}
              onChange={(event) => setDraft({...draft, [field.key]: event.target.checked})}
              className="mt-1"
            />
            <span>
              <span className="font-medium">{field.label}</span>{" "}
              <span className="font-mono text-xs text-slate-500">{field.key}</span>
              <span className="block text-xs text-slate-500">{field.help}</span>
            </span>
          </label>
        ))}
      </div>
      <h2 className="mt-6 font-semibold">앱 최소 버전</h2>
      <div className="mt-2 rounded-xl border border-slate-200 bg-white p-4">
        <label className="block text-sm">
          <span className="font-medium">앱 최소 버전</span>{" "}
          <span className="font-mono text-xs text-slate-500">minAppVersion</span>
          <input
            type="text"
            value={draft.minAppVersion}
            onChange={(event) => setDraft({...draft, minAppVersion: event.target.value})}
            aria-invalid={!APP_VERSION_PATTERN.test(draft.minAppVersion)}
            className={`mt-1 block w-28 rounded-md border px-2 py-1 ${
              APP_VERSION_PATTERN.test(draft.minAppVersion) ? "border-slate-300" : "border-red-500"
            }`}
          />
          <span className="mt-1 block text-xs text-slate-500">
            이보다 낮은 앱(안드로이드, iOS)을 다음에 켤 때 업데이트 화면을 띄워요. 서버는 막지 않아요.
          </span>
          {!APP_VERSION_PATTERN.test(draft.minAppVersion) && (
            <span className="block text-xs text-red-700">⚠ 1.2.3 모양으로 적어 주세요.</span>
          )}
        </label>
      </div>
      <h2 className="mt-6 font-semibold">공지</h2>
      <div className="mt-2 space-y-3 rounded-xl border border-slate-200 bg-white p-4 text-sm">
        <label className="flex items-start gap-2">
          <input
            type="checkbox"
            checked={draft.noticeEnabled}
            onChange={(event) => setDraft({...draft, noticeEnabled: event.target.checked})}
            className="mt-1"
          />
          <span>
            <span className="font-medium">공지 띄우기</span>{" "}
            <span className="font-mono text-xs text-slate-500">serviceNotice</span>
          </span>
        </label>
        {draft.noticeEnabled && (
          <>
            <label className="block">
              <span className="font-medium">한국어</span>
              <textarea
                value={draft.noticeMessageKo}
                maxLength={SERVICE_NOTICE_MAX_LENGTH}
                rows={2}
                onChange={(event) => setDraft({...draft, noticeMessageKo: event.target.value})}
                aria-invalid={!isNoticeMessageValid(draft.noticeMessageKo)}
                className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1"
              />
            </label>
            <label className="block">
              <span className="font-medium">영어</span>
              <textarea
                value={draft.noticeMessageEn}
                maxLength={SERVICE_NOTICE_MAX_LENGTH}
                rows={2}
                onChange={(event) => setDraft({...draft, noticeMessageEn: event.target.value})}
                aria-invalid={!isNoticeMessageValid(draft.noticeMessageEn)}
                className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1"
              />
            </label>
            {!isNoticeValid(draft) && <p className="text-xs text-red-700">⚠ 두 언어를 모두 적어 주세요.</p>}
            <label className="flex items-start gap-2">
              <input
                type="checkbox"
                checked={draft.noticeGamesBlocked}
                onChange={(event) => setDraft({...draft, noticeGamesBlocked: event.target.checked})}
                className="mt-1"
              />
              <span>
                <span className="font-medium">새 대국 막기</span>{" "}
                <span className="font-mono text-xs text-slate-500">gamesBlocked</span>
                <span className="block text-xs text-slate-500">진행 중인 대국은 그대로 두고 새 대국만 막아요.</span>
              </span>
            </label>
          </>
        )}
      </div>
      <h2 className="mt-6 font-semibold">엽전</h2>
      <div className="mt-2 space-y-4 rounded-xl border border-slate-200 bg-white p-4">
        {COIN_FIELDS.map(renderNumberField)}
      </div>
      {error !== null && (
        <p role="alert" className="mt-2 text-sm text-red-700">
          ⚠ {error}
        </p>
      )}
      <div className="mt-4 flex gap-2">
        <button
          type="button"
          onClick={() => setConfirming(true)}
          disabled={nextConfig === null || changedKeys.length === 0 || saving}
          className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-40"
        >
          검토하기
        </button>
        <button
          type="button"
          onClick={() => setDraft(toDraft(serverConfig))}
          disabled={changedKeys.length === 0 || saving}
          className="rounded-md border border-slate-300 px-4 py-2 text-sm disabled:opacity-40"
        >
          되돌리기
        </button>
      </div>
      {confirming && nextConfig !== null && (
        <ConfirmDialog
          title="설정을 바꿀까요?"
          confirmLabel="바꾸기"
          busy={saving}
          onConfirm={() => void submit(nextConfig)}
          onCancel={() => setConfirming(false)}
        >
          <ul className="space-y-1">
            {changedKeys.map((key) => (
              <li key={key}>
                <span className="font-mono text-xs">{key}</span>: {formatValue(serverConfig, key)} →{" "}
                <strong>{formatValue(nextConfig, key)}</strong>
              </li>
            ))}
          </ul>
          <p className="text-slate-500">서버는 캐시 때문에 1분 안에 새 값을 써요. 앱 화면은 앱을 다시 켜야 바뀌어요.</p>
        </ConfirmDialog>
      )}
    </div>
  );
}
