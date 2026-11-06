import {useEffect, useState} from "react";
import {ConfirmDialog} from "../components/ConfirmDialog";
import {ErrorState, Loading, getErrorText} from "../components/States";
import {APP_CONFIG_LIMITS} from "../config";
import type {AppConfig} from "../models/admin";
import {AdminApiError} from "../services/adminApi";
import {useConfigStore} from "../stores/configStore";
import {useUiStore} from "../stores/uiStore";

type NumberField = keyof typeof APP_CONFIG_LIMITS;
type BooleanField = "onlineUsersVisible" | "autoSanctionEnabled" | "entryFeeEnabled";

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
  {key: "coinEntryFee", label: "대국 참가비", unit: "엽전", help: "빠른 대국과 신청 대국에서 받아요."},
  {key: "coinWinReward", label: "대국 보상: 승", unit: "엽전"},
  {key: "coinDrawReward", label: "대국 보상: 무승부", unit: "엽전", help: "지금 규칙에 무승부가 없어 쓰이지 않아요."},
  {key: "coinLossReward", label: "대국 보상: 패", unit: "엽전"},
  {key: "coinAttendanceReward", label: "출석", unit: "엽전"},
  {key: "coinAttendanceStreakReward", label: "출석: 연속 7일째", unit: "엽전", help: "평소 출석 값 대신 줘요."},
  {key: "coinRescueReward", label: "바닥 구제", unit: "엽전"},
  {key: "coinRescueThreshold", label: "바닥 구제 기준", unit: "엽전", help: "잔액이 이 값 미만이면 하루 한 번 줘요."},
  {key: "coinNicknameChangeCost", label: "닉네임 변경", unit: "엽전", help: "두 번째 변경부터 받아요."},
];

const BOOLEAN_FIELDS: {key: BooleanField; label: string; help: string}[] = [
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
];

/** 폼에 입력 중인 숫자. 비우거나 잘못 적은 값도 그대로 두고 저장 전에 확인한다. */
type Draft = Record<NumberField, string> & Record<BooleanField, boolean>;

function toDraft(config: AppConfig): Draft {
  const numbers = Object.fromEntries(
    [...NUMBER_FIELDS, ...COIN_FIELDS].map(({key}) => [key, String(config[key])]),
  ) as Record<NumberField, string>;
  return {
    ...numbers,
    onlineUsersVisible: config.onlineUsersVisible,
    autoSanctionEnabled: config.autoSanctionEnabled,
    entryFeeEnabled: config.entryFeeEnabled,
  };
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
  return {
    ...numbers,
    onlineUsersVisible: draft.onlineUsersVisible,
    autoSanctionEnabled: draft.autoSanctionEnabled,
    entryFeeEnabled: draft.entryFeeEnabled,
  };
}

function formatValue(config: AppConfig, key: keyof AppConfig): string {
  const value = config[key];
  if (typeof value === "boolean") {
    return value ? "● 켬" : "○ 끔";
  }
  return String(value);
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
      : (Object.keys(serverConfig) as (keyof AppConfig)[]).filter((key) => serverConfig[key] !== nextConfig[key]);

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
          <p className="text-slate-500">모든 사용자에게 바로 적용돼요. 서버는 캐시 때문에 1분 안에 새 값을 써요.</p>
        </ConfirmDialog>
      )}
    </div>
  );
}
