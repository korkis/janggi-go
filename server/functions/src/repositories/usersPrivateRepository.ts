import {Timestamp, Transaction, getFirestore} from "firebase-admin/firestore";
import {ActiveSanction, UserPrivate} from "../models/userPrivate";
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

export function deleteUserPrivateInTransaction(transaction: Transaction, uid: string): void {
  transaction.delete(userPrivateRef(uid));
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

/** 지금 걸린 제재를 바꾼다. null이면 지운다. */
export function updateSanctionInTransaction(
  transaction: Transaction,
  uid: string,
  sanction: ActiveSanction | null,
): void {
  transaction.update(userPrivateRef(uid), {sanction});
}

/**
 * 제재가 [now] 전에 끝난 사용자. 경고와 영구 정지는 `endsAt`이 null이라 들어오지 않는다. `sanction.endsAt` 단일 필드 색인을 쓴다.
 */
export async function getUidsWithEndedSanction(now: Timestamp, limit: number): Promise<string[]> {
  const snapshot = await getFirestore().collection(COLLECTION).where("sanction.endsAt", "<=", now).limit(limit).get();
  return snapshot.docs.map((doc) => doc.id);
}
