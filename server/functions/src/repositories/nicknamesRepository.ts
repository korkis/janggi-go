import {Transaction, getFirestore} from "firebase-admin/firestore";
import {Nickname} from "../models/nickname";
import {modelConverter} from "./firestore";

const COLLECTION = "nicknames";

function nicknameRef(nicknameKey: string) {
  return getFirestore().collection(COLLECTION).doc(nicknameKey).withConverter(modelConverter<Nickname>());
}

export async function getNickname(nicknameKey: string): Promise<Nickname | null> {
  const snapshot = await nicknameRef(nicknameKey).get();
  return snapshot.data() ?? null;
}

export async function getNicknameInTransaction(transaction: Transaction, nicknameKey: string): Promise<Nickname | null> {
  const snapshot = await transaction.get(nicknameRef(nicknameKey));
  return snapshot.data() ?? null;
}

export function createNicknameInTransaction(transaction: Transaction, nicknameKey: string, nickname: Nickname): void {
  transaction.create(nicknameRef(nicknameKey), nickname);
}
