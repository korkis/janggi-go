// 서버만 쓰고 운영 중 바꿀 일이 없는 설정이다(docs/dev_rules.md의 설정 저장).

// configs/app 문서를 메모리에 캐시하는 시간(초). 요청마다 Firestore를 읽지 않기 위해서다.
export const APP_CONFIG_CACHE_SECONDS = 60;

// 닉네임 최소 글자 수(docs/screens.md의 닉네임 정하기).
export const NICKNAME_MIN_LENGTH = 2;

// 닉네임 최대 글자 수.
export const NICKNAME_MAX_LENGTH = 10;

// 닉네임에 쓸 수 있는 글자. 완성된 한글, 영문, 숫자만 허용한다.
export const NICKNAME_PATTERN = /^[가-힣A-Za-z0-9]+$/;

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

// 자체 금칙어. 채팅 검사(11단계)의 목록을 둘 곳이 정해지면 그쪽으로 옮긴다(docs/database.md의 미정).
export const BANNED_WORDS = ["씨발", "시발", "씨바", "병신", "븅신", "개새끼", "개새", "좆", "존나", "fuck", "shit"];
