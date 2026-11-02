import dayjs from "dayjs";
import {getFirestore} from "firebase-admin/firestore";
import {APP_CONFIG_CACHE_SECONDS} from "../config";
import {AppConfig} from "../models/appConfig";
import {modelConverter} from "./firestore";

const COLLECTION = "configs";
const APP_CONFIG_ID = "app";

// 마지막으로 읽은 configs/app과 읽은 시각(epoch ms).
let cachedAppConfig: {config: AppConfig; loadedAt: number} | null = null;

function appConfigRef() {
  return getFirestore().collection(COLLECTION).doc(APP_CONFIG_ID).withConverter(modelConverter<AppConfig>());
}

/** configs/app을 읽는다. APP_CONFIG_CACHE_SECONDS 동안은 메모리 캐시를 쓴다. 문서가 없으면 오류를 던진다. */
export async function getAppConfig(): Promise<AppConfig> {
  const now = dayjs().valueOf();
  if (cachedAppConfig !== null && now - cachedAppConfig.loadedAt < APP_CONFIG_CACHE_SECONDS * 1000) {
    return cachedAppConfig.config;
  }
  const snapshot = await appConfigRef().get();
  const config = snapshot.data();
  if (config === undefined) {
    throw new Error("configs/app 문서가 없습니다");
  }
  cachedAppConfig = {config, loadedAt: now};
  return config;
}

/** configs/app이 없을 때만 [config]로 만든다. 만들었으면 true. */
export async function createAppConfigIfAbsent(config: AppConfig): Promise<boolean> {
  try {
    await appConfigRef().create(config);
    return true;
  } catch (error) {
    // 이미 있으면 ALREADY_EXISTS(6)로 실패한다.
    if ((error as {code?: unknown}).code === 6) {
      return false;
    }
    throw error;
  }
}
