import {Timestamp, Transaction, getFirestore} from "firebase-admin/firestore";
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

export async function getUserPrivateInTransaction(transaction: Transaction, uid: string): Promise<UserPrivate | null> {
  const snapshot = await transaction.get(userPrivateRef(uid));
  return snapshot.data() ?? null;
}

/** 닉네임을 바꾼 횟수와 시각을 쓴다. */
export function updateNicknameChangeInTransaction(
  transaction: Transaction,
  uid: string,
  nicknameChangeCount: number,
  nicknameChangedAt: Timestamp,
): void {
  transaction.update(userPrivateRef(uid), {nicknameChangeCount, nicknameChangedAt});
}

export function createUserPrivateInTransaction(transaction: Transaction, uid: string, userPrivate: UserPrivate): void {
  transaction.create(userPrivateRef(uid), userPrivate);
}
