import {Timestamp} from "firebase-admin/firestore";

/** 채팅 종류. 앱의 `ChatChannel`과 값을 일치시킨다(docs/database.md의 공통 enum). */
export const ChatChannel = {
  lobby: "lobby",
  game: "game",
  spectator: "spectator",
} as const;
export type ChatChannel = (typeof ChatChannel)[keyof typeof ChatChannel];

/**
 * 채팅 Callable이 거절한 이유. 오류의 `details.code`로 앱에 보낸다. 앱의 `ChatErrorCode`와 값을 일치시킨다.
 * 앱은 모르는 값을 받으면 그 작업의 기본 오류 메시지를 보여준다.
 */
export const ChatErrorCode = {
  // 닉네임을 아직 정하지 않았다.
  profileRequired: "profileRequired",
  // 이용 정지 또는 영구 정지 중이다.
  sanctioned: "sanctioned",
  // 채팅 제한 중이다.
  chatRestricted: "chatRestricted",
  // 대국이나 메시지가 없다.
  notFound: "notFound",
  // 이 채팅을 읽거나 쓸 수 없다(대국자가 아닌 대국 채팅, 대국 중인 대국자의 관전 채팅, 내 메시지 신고).
  notAllowed: "notAllowed",
  // 금칙어나 OpenAI Moderation에 걸려 저장하지 않았다.
  messageBlocked: "messageBlocked",
  // 메시지를 검사하지 못해 저장하지 않았다.
  moderationUnavailable: "moderationUnavailable",
  // 운영 스위치(`chatEnabled`, `webEnabled`)로 멈췄다.
  featureDisabled: "featureDisabled",
} as const;
export type ChatErrorCode = (typeof ChatErrorCode)[keyof typeof ChatErrorCode];

/**
 * RTDB `chats_lobby/{messageId}`, `chats_game/{gameId}/{messageId}`, `chats_spectator/{gameId}/{messageId}`.
 * 세 경로의 모양이 같다. 필드는 앱의 `ChatMessage`(app/lib/models/chat_message.dart)와 일치시킨다.
 */
export interface ChatMessage {
  uid: string;
  // 보낼 때의 닉네임.
  nickname: string;
  text: string;
  // 서버가 받은 시각(epoch ms).
  sentAt: number;
}

/** OpenAI Moderation의 분류별 점수. 분류 이름은 API가 돌려준 그대로다. */
export type ModerationScores = Record<string, number>;

/** Firestore `chat_checks/{messageId}`. 검사를 통과해 저장된 메시지의 검사 결과다(서버 전용). 신고할 때 함께 저장한다. */
export interface ChatCheck {
  scores: ModerationScores;
  bannedWordMatched: boolean;
  // 채팅과 같이 지운다. TTL 정책으로 지운다.
  expiresAt: Timestamp;
}

/** Firestore `moderation_logs/{logId}`. 검사에 걸린 메시지 기록이다(서버 전용). Admin 웹에서 본다. */
export interface ModerationLog {
  uid: string;
  channel: ChatChannel;
  gameId: string | null;
  // 원문.
  text: string;
  // 걸린 분류. 금칙어에 걸려 OpenAI 검사를 하지 않았으면 비어 있다.
  categories: string[];
  scores: ModerationScores;
  bannedWordMatched: boolean;
  createdAt: Timestamp;
  // TTL 정책으로 지운다.
  expiresAt: Timestamp;
}
