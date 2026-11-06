import {Transaction, getFirestore} from "firebase-admin/firestore";
import {PlayerState} from "../models/account";
import {modelConverter} from "./firestore";

const COLLECTION = "player_states";

function playerStateRef(uid: string) {
  return getFirestore().collection(COLLECTION).doc(uid).withConverter(modelConverter<PlayerState>());
}

export async function getPlayerStateInTransaction(transaction: Transaction, uid: string): Promise<PlayerState | null> {
  const snapshot = await transaction.get(playerStateRef(uid));
  return snapshot.data() ?? null;
}

export function deletePlayerStateInTransaction(transaction: Transaction, uid: string): void {
  transaction.delete(playerStateRef(uid));
}
