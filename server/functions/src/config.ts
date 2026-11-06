// 서버만 쓰고 운영 중 바꿀 일이 없는 설정이다(docs/dev_rules.md의 설정 저장).

// configs/app 문서를 메모리에 캐시하는 시간(초). 요청마다 Firestore를 읽지 않기 위해서다.
export const APP_CONFIG_CACHE_SECONDS = 60;

// 닉네임 최소 글자 수(docs/screens.md의 닉네임 정하기).
export const NICKNAME_MIN_LENGTH = 2;

// 닉네임 최대 글자 수.
export const NICKNAME_MAX_LENGTH = 10;

// 닉네임에 쓸 수 있는 글자. 완성된 한글, 영문, 숫자만 허용한다.
export const NICKNAME_PATTERN = /^[가-힣A-Za-z0-9]+$/;

// 닉네임을 바꾼 뒤 다시 바꿀 수 없는 날 수(docs/screens.md의 내 정보).
export const NICKNAME_CHANGE_COOLDOWN_DAYS = 7;

// 엽전 없이 닉네임을 바꿀 수 있는 횟수. 첫 변경만 무료이고 그 뒤에는 configs/app.coinNicknameChangeCost를 낸다(docs/monetization.md).
export const NICKNAME_FREE_CHANGE_COUNT = 1;

// 연속 출석의 한 바퀴. 이 날에는 configs/app.coinAttendanceStreakReward를 주고 다음 날 1부터 다시 센다(docs/monetization.md).
export const COIN_ATTENDANCE_STREAK_DAYS = 7;

// 출석과 바닥 구제의 "하루"가 바뀌는 시간대의 UTC 차이(시간). 서울 시간 0시다. 대국 서버의 coinDayUtcOffset과 같다.
export const COIN_DAY_UTC_OFFSET_HOURS = 9;

// Admin 웹의 잔액 분포 구간 시작값. 마지막 구간은 위가 열려 있다.
export const COIN_BALANCE_BUCKET_STARTS = [0, 10, 50, 100, 300, 1000, 3000];

// Admin 웹의 엽전 지표가 하루 단위로 보여주는 날 수. 오늘 포함이다.
export const COIN_STATS_DAYS = 7;

// 운영진을 사칭하는 단어. 닉네임에 들어 있으면(영문은 대소문자 무시) 쓸 수 없다.
export const NICKNAME_IMPERSONATION_WORDS = [
  "운영자",
  "운영진",
  "운영팀",
  "관리자",
  "어드민",
  "admin",
  "장기고",
  "janggigo",
  "공식",
  "official",
  "staff",
];

// 자체 금칙어. 닉네임과 채팅이 같이 쓴다. OpenAI Moderation이 놓치는 한국어 은어와 초성 욕설을 거른다(docs/moderation.md).
// 숫자와 기호를 지우고 한 글자씩 띄어 쓴 것을 붙인 글에서 찾는다(services/bannedWordService.ts). 영문은 소문자로 적는다.
// 띄어 쓴 낱말끼리 붙여 보지는 않으므로 두 글자 금칙어도 "아저씨 발"처럼 낱말 경계에 걸리지 않는다.
export const BANNED_WORDS = [
  "씨발",
  "시발",
  "씨바",
  "씨빨",
  "ㅅㅂ",
  "ㅆㅂ",
  "ㅅㅃ",
  "병신",
  "븅신",
  "빙신",
  "ㅂㅅ",
  "ㅄ",
  "개새끼",
  "개새",
  "개색기",
  "개세끼",
  "ㄱㅅㄲ",
  "좆",
  "존나",
  "졸라",
  "ㅈㄴ",
  "지랄",
  "ㅈㄹ",
  "미친놈",
  "미친년",
  "애미",
  "느금",
  "엠창",
  "fuck",
  "shit",
  "bitch",
  // 아래는 2026-11-03 실제 OpenAI 검사에서 통과해 버린 표현이다(docs/moderation.md의 실제 검사 확인).
  "시바",
  "씨빠",
  "ㄲㅈ",
  "ㅗㅗ",
  "닥쳐",
  "벌레같",
  "한남충",
  "김치녀",
  "틀딱",
  "뒤져라",
  "뒤질래",
  "대가리",
  // 띄어쓰기가 있는 구절은 띄어쓰기를 모두 지운 글에서 찾는다.
  "집 찾아간",
];

// 금칙어를 품고 있지만 평범한 낱말. 금칙어를 찾기 전에 지운다.
export const BANNED_WORD_EXCEPTIONS = ["시발점", "시발역", "시발택시", "시바견"];

// OpenAI Moderation 모델 이름(docs/moderation.md).
export const MODERATION_MODEL = "omni-moderation-latest";

// OpenAI Moderation API 주소.
export const MODERATION_API_URL = "https://api.openai.com/v1/moderations";

// OpenAI Moderation 응답을 기다리는 최대 시간(밀리초). 넘으면 메시지를 보내지 못한 것으로 본다.
export const MODERATION_TIMEOUT_MS = 5000;

// 채팅 메시지 최대 글자 수. 앞뒤 공백을 지우고 센다(docs/server.md의 sendChatMessage).
export const CHAT_MAX_LENGTH = 100;

// 채팅과 통과한 메시지의 검사 결과(chat_checks)를 남겨 두는 날 수(docs/moderation.md의 보관 기간).
export const CHAT_RETENTION_DAYS = 90;

// 검사에 걸린 메시지 기록(moderation_logs)과 처리가 끝난 신고를 남겨 두는 날 수.
export const MODERATION_LOG_RETENTION_DAYS = 365;

// 신고할 때 함께 저장하는 앞뒤 메시지 수. 앞과 뒤 각각이다.
export const REPORT_CONTEXT_MESSAGES = 5;

// 채팅을 지우는 예약 작업이 로비 채팅에서 한 번에 읽어 지우는 메시지 수.
export const CHAT_CLEANUP_BATCH_SIZE = 500;

// Realtime Database 인스턴스 주소. 에뮬레이터에서는 Admin SDK가 FIREBASE_DATABASE_EMULATOR_HOST로 보내고 이 주소의
// 인스턴스 이름(ns)만 쓴다. 대국 서버의 RTDB 인스턴스(server/game/lib/server_environment.dart)와 같다.
export const DATABASE_URL = "https://janggi-go-default-rtdb.asia-southeast1.firebasedatabase.app";

// Admin 웹 목록(신고, 검사 기록)을 한 번에 읽는 개수.
export const ADMIN_PAGE_SIZE = 20;

// 신고 상세와 사용자 조회에 함께 보여주는 최근 기록(제재, 신고, 검사 기록, 닉네임 변경) 개수. 종류마다 따로 센다.
export const ADMIN_HISTORY_LIMIT = 20;

// 채팅 제한과 이용 정지에 고를 수 있는 기간(일). 제재 단계 경고 → 1일 → 7일 → 30일 → 영구의 기간 단계다(docs/moderation.md).
export const SANCTION_DURATION_DAYS = [1, 7, 30];

// 조치 사유의 최대 글자 수. 사유는 제재 팝업으로 사용자에게 보인다.
export const ADMIN_REASON_MAX_LENGTH = 200;

// 끝난 제재를 지우는 예약 작업이 한 번에 읽어 지우는 사용자 수.
export const SANCTION_EXPIRE_BATCH_SIZE = 500;

// Admin 웹에서 configs/app에 넣을 수 있는 값의 범위. 앱과 대국 서버가 멈추지 않는 범위로 막는다.
export const APP_CONFIG_LIMITS = {
  disconnectLimitSeconds: {min: 10, max: 300},
  quickRematchLimit: {min: 0, max: 100},
  // 대국 서버는 lastSeenAt이 presenceStaleSeconds(15초)보다 오래되면 끊긴 것으로 본다. 그 안에 세 번 갱신하도록 5초까지만 둔다.
  heartbeatSeconds: {min: 1, max: 5},
  // 엽전 숫자. 실수로 자릿수를 틀려도 경제가 무너지지 않을 만큼만 연다(docs/monetization.md의 숫자).
  coinSignupBonus: {min: 0, max: 3000},
  coinEntryFee: {min: 0, max: 100},
  coinWinReward: {min: 0, max: 100},
  coinDrawReward: {min: 0, max: 100},
  coinLossReward: {min: 0, max: 100},
  coinAttendanceReward: {min: 0, max: 300},
  coinAttendanceStreakReward: {min: 0, max: 1000},
  coinRescueReward: {min: 0, max: 300},
  coinRescueThreshold: {min: 0, max: 100},
  coinNicknameChangeCost: {min: 1, max: 3000},
};
