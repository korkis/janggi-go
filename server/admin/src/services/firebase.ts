import {type FirebaseOptions, initializeApp} from "firebase/app";
import {connectAuthEmulator, getAuth} from "firebase/auth";
import {connectFunctionsEmulator, getFunctions} from "firebase/functions";
import {EMULATOR, FUNCTIONS_REGION, USE_FIREBASE_EMULATOR} from "../config";

/**
 * Firebase 웹 설정. 개발 서버는 에뮬레이터의 demo 프로젝트를 쓰고(키는 에뮬레이터가 검사하지 않는 형식상의 값), 운영 빌드는
 * `.env.production.local`의 `VITE_FIREBASE_*`를 쓴다. 운영 값이 없으면 바로 실패한다.
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
  const env = import.meta.env;
  const {VITE_FIREBASE_API_KEY, VITE_FIREBASE_AUTH_DOMAIN, VITE_FIREBASE_PROJECT_ID, VITE_FIREBASE_APP_ID} = env;
  if (!VITE_FIREBASE_API_KEY || !VITE_FIREBASE_AUTH_DOMAIN || !VITE_FIREBASE_PROJECT_ID || !VITE_FIREBASE_APP_ID) {
    throw new Error("운영 Firebase 설정(VITE_FIREBASE_*)이 없습니다");
  }
  return {
    apiKey: VITE_FIREBASE_API_KEY,
    authDomain: VITE_FIREBASE_AUTH_DOMAIN,
    projectId: VITE_FIREBASE_PROJECT_ID,
    appId: VITE_FIREBASE_APP_ID,
  };
}

const app = initializeApp(getFirebaseOptions());

export const auth = getAuth(app);
export const functions = getFunctions(app, FUNCTIONS_REGION);

if (USE_FIREBASE_EMULATOR) {
  connectAuthEmulator(auth, `http://${EMULATOR.host}:${EMULATOR.authPort}`, {disableWarnings: true});
  connectFunctionsEmulator(functions, EMULATOR.host, EMULATOR.functionsPort);
}
