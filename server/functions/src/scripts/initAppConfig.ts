import {initializeApp} from "firebase-admin/app";
import {INITIAL_APP_CONFIG} from "../models/appConfig";
import {fillMissingAppConfig} from "../repositories/configsRepository";

/**
 * configs/app에 없는 필드를 처음 값으로 채운다. 문서가 없으면 만들고, 이미 있는 값은 바꾸지 않는다.
 * 필드가 늘어난 서버를 배포하기 전에 실행한다(docs/server.md의 configs/app).
 * 에뮬레이터: FIRESTORE_EMULATOR_HOST와 GCLOUD_PROJECT를 정하고 실행한다. 운영: 사용자가 직접 실행한다.
 */
async function main(): Promise<void> {
  initializeApp();
  const filled = await fillMissingAppConfig(INITIAL_APP_CONFIG);
  console.log(filled.length > 0 ? `configs/app 채움: ${filled.join(", ")}` : "configs/app에 빠진 필드가 없어 바꾸지 않음");
}

main().catch((error: unknown) => {
  console.error("initAppConfig 실패", error);
  process.exitCode = 1;
});
