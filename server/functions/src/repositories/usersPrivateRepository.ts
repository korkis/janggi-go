import {Transaction, getFirestore} from "firebase-admin/firestore";
import {UserPrivate} from "../models/userPrivate";
import {modelConverter} from "./firestore";

const COLLECTION = "users_private";

function userPrivateRef(uid: string) {
  return getFirestore().collection(COLLECTION).doc(uid).withConverter(modelConverter<UserPrivate>());
}

export async function getUserPrivate(uid: string): Promise<UserPrivate | null> {
  const snapshot = await userPrivateRef(uid).get();
  return snapshot.data() ?? null;
}

export function createUserPrivateInTransaction(transaction: Transaction, uid: string, userPrivate: UserPrivate): void {
  transaction.create(userPrivateRef(uid), userPrivate);
}
