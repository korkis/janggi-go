import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {AdminErrorCode} from "../models/admin";
import {AppConfig} from "../models/appConfig";
import {getAppConfigUncached} from "../repositories/configsRepository";
import {requireAdmin} from "./auth";

/** Admin 웹의 설정 화면. `configs/app`의 지금 값을 캐시 없이 읽는다. 문서가 없으면 notFound. */
export const adminGetAppConfig = onCall(async (request): Promise<AppConfig> => {
  const adminUid = requireAdmin(request);
  const config = await getAppConfigUncached();
  if (config === null) {
    throw new HttpsError("not-found", "configs/app이 없습니다", {code: AdminErrorCode.notFound});
  }
  logger.info("adminGetAppConfig 완료", {adminUid});
  return config;
});
