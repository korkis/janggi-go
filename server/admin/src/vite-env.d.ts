/// <reference types="vite/client" />

interface ImportMetaEnv {
  // "false"면 개발 서버도 에뮬레이터 대신 운영 프로젝트에 붙는다.
  readonly VITE_USE_FIREBASE_EMULATOR?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
