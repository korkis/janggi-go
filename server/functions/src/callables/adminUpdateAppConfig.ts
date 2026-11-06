import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {APP_CONFIG_LIMITS, APP_VERSION_PATTERN, SERVICE_NOTICE_MAX_LENGTH} from "../config";
import {AppConfig, INITIAL_APP_CONFIG} from "../models/appConfig";
import {setAppConfig} from "../repositories/configsRepository";
import {requireAdmin} from "./auth";

interface AdminUpdateAppConfigParams {
  // 바꾼 뒤의 모든 필드. 빠진 필드가 없어야 한다.
  config: AppConfig;
}

// 범위 검사(APP_CONFIG_LIMITS)를 하는 숫자 필드.
const NUMBER_KEYS = Object.keys(APP_CONFIG_LIMITS) as (keyof typeof APP_CONFIG_LIMITS)[];
// boolean 필드.
const BOOLEAN_KEYS: (keyof AppConfig)[] = [
  "onlineUsersVisible",
  "autoSanctionEnabled",
  "entryFeeEnabled",
  "timeExtensionEnabled",
  "gamePracticeEnabled",
  "chatEnabled",
  "signupEnabled",
  "webEnabled",
];

/** 공지는 없거나, 두 언어의 문구가 1~SERVICE_NOTICE_MAX_LENGTH자이고 gamesBlocked가 boolean이어야 한다. 필드가 더 있으면 거절한다. */
function validateServiceNotice(value: unknown): void {
  if (value === null) {
    return;
  }
  const fields = (typeof value === "object" ? value : {}) as Record<string, unknown>;
  const valid =
    Object.keys(fields).length === 3 &&
    isServiceNoticeMessage(fields.messageKo) &&
    isServiceNoticeMessage(fields.messageEn) &&
    typeof fields.gamesBlocked === "boolean";
  if (!valid) {
    throw new HttpsError("invalid-argument", "serviceNotice가 올바르지 않습니다");
  }
}

function isServiceNoticeMessage(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0 && value.length <= SERVICE_NOTICE_MAX_LENGTH;
}

function validateRange(value: unknown, name: keyof typeof APP_CONFIG_LIMITS): void {
  const {min, max} = APP_CONFIG_LIMITS[name];
  if (!Number.isInteger(value) || (value as number) < min || (value as number) > max) {
    throw new HttpsError("invalid-argument", `${name}은 ${min}~${max}의 정수여야 합니다`);
  }
}

function validateParams(requestParams: AdminUpdateAppConfigParams): void {
  const config: unknown = requestParams?.config;
  if (typeof config !== "object" || config === null) {
    throw new HttpsError("invalid-argument", "config가 없습니다");
  }
  const fields = config as Record<string, unknown>;
  const expectedKeys = Object.keys(INITIAL_APP_CONFIG);
  const keys = Object.keys(fields);
  if (keys.length !== expectedKeys.length || !expectedKeys.every((key) => keys.includes(key))) {
    throw new HttpsError("invalid-argument", "config 필드가 올바르지 않습니다");
  }
  for (const key of NUMBER_KEYS) {
    validateRange(fields[key], key);
  }
  for (const key of BOOLEAN_KEYS) {
    if (typeof fields[key] !== "boolean") {
      throw new HttpsError("invalid-argument", "config의 boolean 필드가 올바르지 않습니다");
    }
  }
  if (typeof fields.minAppVersion !== "string" || !APP_VERSION_PATTERN.test(fields.minAppVersion)) {
    throw new HttpsError("invalid-argument", "minAppVersion은 1.2.3 모양이어야 합니다");
  }
  validateServiceNotice(fields.serviceNotice);
}

/**
 * `configs/app`을 바꾼다(docs/dev_rules.md의 설정 저장: 쓰기는 Admin 웹의 Callable만 한다). 결과는 바꾼 값이다.
 * Functions와 대국 서버는 캐시 시간(60초)이 지나야 새 값을 쓰고, 대국 중 끊김 허용 시간은 새로 만드는 대국부터 바뀐다.
 */
export const adminUpdateAppConfig = onCall<AdminUpdateAppConfigParams>(async (request): Promise<AppConfig> => {
  const requestParams = request.data;
  const adminUid = requireAdmin(request);
  validateParams(requestParams);
  const config = requestParams.config;
  await setAppConfig(config);
  logger.info("adminUpdateAppConfig 완료", {adminUid, ...config});
  return config;
});
