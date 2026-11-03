/// <reference types="vite/client" />

// 운영 빌드의 Firebase 웹 설정. 비밀값이 아니지만 저장소에 넣지 않고 `.env.production.local`에 둔다(docs/server.md의 Admin 웹).
interface ImportMetaEnv {
  readonly VITE_FIREBASE_API_KEY?: string;
  readonly VITE_FIREBASE_AUTH_DOMAIN?: string;
  readonly VITE_FIREBASE_PROJECT_ID?: string;
  readonly VITE_FIREBASE_APP_ID?: string;
  // "false"면 개발 서버도 에뮬레이터 대신 운영 프로젝트에 붙는다.
  readonly VITE_USE_FIREBASE_EMULATOR?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
