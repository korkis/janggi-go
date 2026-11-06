import dayjs from "dayjs";
import {getFirestore} from "firebase-admin/firestore";
import {APP_CONFIG_CACHE_SECONDS} from "../config";
import {AppConfig} from "../models/appConfig";
import {modelConverter, runTransaction} from "./firestore";

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

/** configs/app을 캐시 없이 읽는다. Admin 웹이 지금 값을 보여줄 때 쓴다. 문서가 없으면 null. */
export async function getAppConfigUncached(): Promise<AppConfig | null> {
  const snapshot = await appConfigRef().get();
  return snapshot.data() ?? null;
}

/** configs/app을 [config]로 바꾼다. 이 인스턴스의 캐시는 비운다. 다른 인스턴스와 대국 서버는 캐시 시간이 지나면 새 값을 읽는다. */
export async function setAppConfig(config: AppConfig): Promise<void> {
  await appConfigRef().set(config);
  cachedAppConfig = null;
}

/**
 * configs/app에 없는 필드만 [config]의 값으로 채운다. 문서가 없으면 만든다. 이미 있는 값은 바꾸지 않는다. 채운 필드 이름을 돌려준다.
 * 필드가 늘어난 서버를 배포하기 전에 부른다. 앱과 서버가 모든 필드를 필수로 읽기 때문이다.
 */
export async function fillMissingAppConfig(config: AppConfig): Promise<string[]> {
  const ref = appConfigRef();
  return runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current: Partial<AppConfig> = snapshot.data() ?? {};
    const missing = Object.entries(config).filter(([key]) => !(key in current));
    if (missing.length > 0) {
      transaction.set(ref, {...current, ...Object.fromEntries(missing)} as AppConfig);
    }
    return missing.map(([key]) => key);
  });
}
