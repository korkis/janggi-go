import {getFirestore} from "firebase-admin/firestore";
import {ChatCheck} from "../models/chat";
import {modelConverter} from "./firestore";

const COLLECTION = "chat_checks";

function chatCheckRef(messageId: string) {
  return getFirestore().collection(COLLECTION).doc(messageId).withConverter(modelConverter<ChatCheck>());
}

export async function getChatCheck(messageId: string): Promise<ChatCheck | null> {
  const snapshot = await chatCheckRef(messageId).get();
  return snapshot.data() ?? null;
}

export async function createChatCheck(messageId: string, check: ChatCheck): Promise<void> {
  await chatCheckRef(messageId).create(check);
}
