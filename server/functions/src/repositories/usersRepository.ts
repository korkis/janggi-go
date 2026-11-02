import {Transaction, getFirestore} from "firebase-admin/firestore";
import {User} from "../models/user";
import {modelConverter} from "./firestore";

const COLLECTION = "users";

function userRef(uid: string) {
  return getFirestore().collection(COLLECTION).doc(uid).withConverter(modelConverter<User>());
}

export async function getUserInTransaction(transaction: Transaction, uid: string): Promise<User | null> {
  const snapshot = await transaction.get(userRef(uid));
  return snapshot.data() ?? null;
}

export function createUserInTransaction(transaction: Transaction, uid: string, user: User): void {
  transaction.create(userRef(uid), user);
}
