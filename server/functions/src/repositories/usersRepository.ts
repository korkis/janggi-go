import {Transaction, getFirestore} from "firebase-admin/firestore";
import {User} from "../models/user";
import {modelConverter} from "./firestore";

const COLLECTION = "users";

function userRef(uid: string) {
  return getFirestore().collection(COLLECTION).doc(uid).withConverter(modelConverter<User>());
}

export async function getUser(uid: string): Promise<User | null> {
  const snapshot = await userRef(uid).get();
  return snapshot.data() ?? null;
}

export async function getUserInTransaction(transaction: Transaction, uid: string): Promise<User | null> {
  const snapshot = await transaction.get(userRef(uid));
  return snapshot.data() ?? null;
}

export function createUserInTransaction(transaction: Transaction, uid: string, user: User): void {
  transaction.create(userRef(uid), user);
}

/** 닉네임만 바꾼다. 급수와 전적은 대국 서버가 쓰므로 건드리지 않는다. */
export function updateNicknameInTransaction(transaction: Transaction, uid: string, nickname: string): void {
  transaction.update(userRef(uid), {nickname});
}
