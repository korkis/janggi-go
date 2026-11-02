import {initializeApp} from "firebase-admin/app";
import {AppConfig} from "../models/appConfig";
import {createAppConfigIfAbsent} from "../repositories/configsRepository";

// configs/app의 처음 값(docs/server.md의 "configs/app").
const INITIAL_APP_CONFIG: AppConfig = {
  disconnectLimitSeconds: 30,
  quickRematchLimit: 5,
  onlineUsersVisible: false,
  autoSanctionEnabled: false,
  heartbeatSeconds: 5,
};

/**
 * configs/app이 없으면 처음 값으로 만든다. 이미 있으면 바꾸지 않는다.
 * 에뮬레이터: FIRESTORE_EMULATOR_HOST와 GCLOUD_PROJECT를 정하고 실행한다. 운영: 사용자가 직접 실행한다.
 */
async function main(): Promise<void> {
  initializeApp();
  const created = await createAppConfigIfAbsent(INITIAL_APP_CONFIG);
  console.log(created ? "configs/app 생성 완료" : "configs/app이 이미 있어 바꾸지 않음");
}

main().catch((error: unknown) => {
  console.error("initAppConfig 실패", error);
  process.exitCode = 1;
});
