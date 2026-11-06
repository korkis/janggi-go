// Admin 웹만 쓰고 운영 중 바꿀 일이 없는 설정이다.

/** Functions 리전. Functions의 setGlobalOptions(server/functions/src/setup.ts)와 같다. */
export const FUNCTIONS_REGION = "asia-northeast3";

/** 개발 서버(`npm run dev`)는 Firebase Emulator Suite에 붙는다(docs/dev_rules.md의 개발 환경). */
export const USE_FIREBASE_EMULATOR = import.meta.env.DEV && import.meta.env.VITE_USE_FIREBASE_EMULATOR !== "false";

/**
 * 운영 프로젝트(janggi-go)의 Admin 웹 앱 설정. Firebase 콘솔의 "장기고 Admin" 웹 앱 설정이다. 비밀값이 아니라(브라우저 번들에
 * 그대로 들어간다) 저장소에 둔다. 접근은 Auth의 admin claim과 Callable이 막는다.
 */
export const PRODUCTION_FIREBASE_OPTIONS = {
  apiKey: "AIzaSyBmzZ_7ELq-XQTgi-uIIYPekeZ2cvoBStE",
  authDomain: "janggi-go.firebaseapp.com",
  projectId: "janggi-go",
  appId: "1:724506591713:web:3f352372639fbd93d712a0",
};

/** 에뮬레이터의 프로젝트와 포트. server/firebase.json, server/functions의 `npm run emulators`와 같다. */
export const EMULATOR = {
  projectId: "demo-janggi-go",
  host: "127.0.0.1",
  authPort: 9099,
  functionsPort: 5001,
};

/** 채팅 제한과 이용 정지에 고를 수 있는 기간(일). Functions의 SANCTION_DURATION_DAYS와 같다. */
export const SANCTION_DURATION_DAYS = [1, 7, 30];

/** 조치 사유의 최대 글자 수. Functions의 ADMIN_REASON_MAX_LENGTH와 같다. */
export const REASON_MAX_LENGTH = 200;

/** configs/app에 넣을 수 있는 값의 범위. Functions의 APP_CONFIG_LIMITS와 같다. */
export const APP_CONFIG_LIMITS = {
  disconnectLimitSeconds: {min: 10, max: 300},
  quickRematchLimit: {min: 0, max: 100},
  heartbeatSeconds: {min: 1, max: 5},
  coinSignupBonus: {min: 0, max: 3000},
  coinEntryFee: {min: 0, max: 100},
  coinWinReward: {min: 0, max: 100},
  coinLossReward: {min: 0, max: 100},
  coinAttendanceReward: {min: 0, max: 300},
  coinAttendanceStreakReward: {min: 0, max: 1000},
  coinNicknameChangeCost: {min: 1, max: 3000},
};
