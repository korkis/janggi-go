import {DataSnapshot, Reference} from "firebase-admin/database";
import {ChatChannel, ChatMessage} from "../models/chat";
import {getRtdb, getShallowKeys} from "./rtdb";

// 세 채팅 경로는 같은 메시지 모양의 변형이라(docs/dev_rules.md의 DB 명명) 한 repository가 채팅 종류로 경로를 고른다.
const PATHS: Record<ChatChannel, string> = {
  lobby: "chats_lobby",
  game: "chats_game",
  spectator: "chats_spectator",
};

/** 대국별로 경로가 나뉘는 채팅. */
export type GameChatChannel = typeof ChatChannel.game | typeof ChatChannel.spectator;

export interface ChatMessageEntry {
  messageId: string;
  message: ChatMessage;
}

/** 한 채팅의 메시지가 모인 곳. 로비 채팅은 [gameId]가 null이고, 대국·관전 채팅은 대국별이다. */
function chatRef(channel: ChatChannel, gameId: string | null): Reference {
  const path = gameId === null ? PATHS[channel] : `${PATHS[channel]}/${gameId}`;
  return getRtdb().ref(path);
}

function toEntries(snapshot: DataSnapshot): ChatMessageEntry[] {
  const entries: ChatMessageEntry[] = [];
  snapshot.forEach((child) => {
    entries.push({messageId: child.key, message: child.val() as ChatMessage});
  });
  return entries;
}

/** 새 메시지 ID. RTDB push 키라 보낸 순서대로 정렬된다. 아직 쓰지 않는다. */
export function createMessageId(channel: ChatChannel, gameId: string | null): string {
  return chatRef(channel, gameId).push().key;
}

export async function createMessage(
  channel: ChatChannel,
  gameId: string | null,
  messageId: string,
  message: ChatMessage,
): Promise<void> {
  await chatRef(channel, gameId).child(messageId).set(message);
}

export async function getMessage(
  channel: ChatChannel,
  gameId: string | null,
  messageId: string,
): Promise<ChatMessage | null> {
  const snapshot = await chatRef(channel, gameId).child(messageId).get();
  return snapshot.exists() ? (snapshot.val() as ChatMessage) : null;
}

/** [messageId] 바로 앞의 메시지 [limit]개. 보낸 순서대로다. */
export async function getMessagesBefore(
  channel: ChatChannel,
  gameId: string | null,
  messageId: string,
  limit: number,
): Promise<ChatMessageEntry[]> {
  return toEntries(await chatRef(channel, gameId).orderByKey().endBefore(messageId).limitToLast(limit).get());
}

/** [messageId] 바로 뒤의 메시지 [limit]개. 보낸 순서대로다. */
export async function getMessagesAfter(
  channel: ChatChannel,
  gameId: string | null,
  messageId: string,
  limit: number,
): Promise<ChatMessageEntry[]> {
  return toEntries(await chatRef(channel, gameId).orderByKey().startAfter(messageId).limitToFirst(limit).get());
}

/** [sentAtBefore]보다 먼저 보낸 로비 메시지 ID를 [limit]개까지. `chats_lobby`의 `sentAt` 색인을 쓴다. */
export async function getOldLobbyMessageIds(sentAtBefore: number, limit: number): Promise<string[]> {
  const snapshot = await chatRef(ChatChannel.lobby, null)
    .orderByChild("sentAt")
    .endBefore(sentAtBefore)
    .limitToFirst(limit)
    .get();
  return toEntries(snapshot).map((entry) => entry.messageId);
}

export async function deleteLobbyMessages(messageIds: string[]): Promise<void> {
  const updates: Record<string, null> = {};
  for (const messageId of messageIds) {
    updates[messageId] = null;
  }
  await chatRef(ChatChannel.lobby, null).update(updates);
}

/** 대국·관전 채팅이 있는 대국 ID. 메시지는 읽지 않는다. */
export function getChatGameIds(channel: GameChatChannel): Promise<string[]> {
  return getShallowKeys(PATHS[channel]);
}

/** 한 대국 채팅의 마지막 메시지. 없으면 null. */
export async function getLatestMessage(channel: GameChatChannel, gameId: string): Promise<ChatMessage | null> {
  const entries = toEntries(await chatRef(channel, gameId).orderByKey().limitToLast(1).get());
  return entries.length === 0 ? null : entries[0].message;
}

/** 한 대국의 채팅을 모두 지운다. */
export async function deleteGameChat(channel: GameChatChannel, gameId: string): Promise<void> {
  await chatRef(channel, gameId).remove();
}
