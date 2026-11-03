import {HttpsError} from "firebase-functions/https";
import {ChatChannel} from "../models/chat";

// RTDB 키로 쓰는 대국 ID와 메시지 ID의 형식. 경로를 벗어나는 글자(`/`, `.` 등)를 막는다.
const KEY_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

/** 채팅 Callable이 함께 받는 채팅 종류와 대국 ID. */
export interface ChatTargetParams {
  channel: ChatChannel;
  // 대국·관전 채팅의 대국. 로비 채팅이면 없다.
  gameId?: string | null;
}

/** [value]가 RTDB 키로 쓸 수 있는 ID인지. */
export function isValidKey(value: unknown): value is string {
  return typeof value === "string" && KEY_PATTERN.test(value);
}

/** 채팅 종류와 대국 ID를 확인한다. 로비 채팅은 대국 ID가 없어야 하고, 대국·관전 채팅은 있어야 한다. */
export function validateChatTarget(requestParams: ChatTargetParams): void {
  const channel: unknown = requestParams?.channel;
  if (typeof channel !== "string" || !Object.values<string>(ChatChannel).includes(channel)) {
    throw new HttpsError("invalid-argument", "channel이 올바르지 않습니다");
  }
  const gameId: unknown = requestParams.gameId ?? null;
  if (channel === ChatChannel.lobby ? gameId !== null : !isValidKey(gameId)) {
    throw new HttpsError("invalid-argument", "gameId가 올바르지 않습니다");
  }
}
