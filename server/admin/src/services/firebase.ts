import {type FirebaseOptions, initializeApp} from "firebase/app";
import {connectAuthEmulator, getAuth} from "firebase/auth";
import {connectFunctionsEmulator, getFunctions} from "firebase/functions";
import {EMULATOR, FUNCTIONS_REGION, PRODUCTION_FIREBASE_OPTIONS, USE_FIREBASE_EMULATOR} from "../config";

/**
 * Firebase 웹 설정. 개발 서버는 에뮬레이터의 demo 프로젝트를 쓰고(키는 에뮬레이터가 검사하지 않는 형식상의 값), 운영 빌드는
 * 운영 프로젝트의 Admin 웹 앱 설정을 쓴다.
 */
function getFirebaseOptions(): FirebaseOptions {
  if (USE_FIREBASE_EMULATOR) {
    return {
      apiKey: "demo-api-key",
      authDomain: `${EMULATOR.projectId}.firebaseapp.com`,
      projectId: EMULATOR.projectId,
      appId: "1:000000000000:web:0000000000000000000000",
    };
  }
  return PRODUCTION_FIREBASE_OPTIONS;
}

const app = initializeApp(getFirebaseOptions());

export const auth = getAuth(app);
export const functions = getFunctions(app, FUNCTIONS_REGION);

if (USE_FIREBASE_EMULATOR) {
  connectAuthEmulator(auth, `http://${EMULATOR.host}:${EMULATOR.authPort}`, {disableWarnings: true});
  connectFunctionsEmulator(functions, EMULATOR.host, EMULATOR.functionsPort);
}
