import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {APP_CONFIG_LIMITS} from "../config";
import {AppConfig} from "../models/appConfig";
import {setAppConfig} from "../repositories/configsRepository";
import {requireAdmin} from "./auth";

interface AdminUpdateAppConfigParams {
  // 바꾼 뒤의 모든 필드. 빠진 필드가 없어야 한다.
  config: AppConfig;
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
  const expectedKeys: (keyof AppConfig)[] = [
    "disconnectLimitSeconds",
    "quickRematchLimit",
    "onlineUsersVisible",
    "autoSanctionEnabled",
    "heartbeatSeconds",
  ];
  const keys = Object.keys(fields);
  if (keys.length !== expectedKeys.length || !expectedKeys.every((key) => keys.includes(key))) {
    throw new HttpsError("invalid-argument", "config 필드가 올바르지 않습니다");
  }
  validateRange(fields.disconnectLimitSeconds, "disconnectLimitSeconds");
  validateRange(fields.quickRematchLimit, "quickRematchLimit");
  validateRange(fields.heartbeatSeconds, "heartbeatSeconds");
  if (typeof fields.onlineUsersVisible !== "boolean" || typeof fields.autoSanctionEnabled !== "boolean") {
    throw new HttpsError("invalid-argument", "config의 boolean 필드가 올바르지 않습니다");
  }
}

/**
 * `configs/app`을 바꾼다(docs/dev_rules.md의 설정 저장: 쓰기는 Admin 웹의 Callable만 한다). 결과는 바꾼 값이다.
 * Functions와 대국 서버는 캐시 시간(60초)이 지나야 새 값을 쓰고, 대국 중 끊김 허용 시간은 새로 만드는 대국부터 바뀐다.
 */
export const adminUpdateAppConfig = onCall<AdminUpdateAppConfigParams>(async (request): Promise<AppConfig> => {
  const requestParams = request.data;
  const adminUid = requireAdmin(request);
  validateParams(requestParams);
  const {disconnectLimitSeconds, quickRematchLimit, onlineUsersVisible, autoSanctionEnabled, heartbeatSeconds} =
    requestParams.config;
  const config = {disconnectLimitSeconds, quickRematchLimit, onlineUsersVisible, autoSanctionEnabled, heartbeatSeconds};
  await setAppConfig(config);
  logger.info("adminUpdateAppConfig 완료", {adminUid, ...config});
  return config;
});
