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

/** 여러 사용자를 한 번에 읽는다. 프로필이 없는 사람은 결과에 없다. */
export async function getUsers(uids: string[]): Promise<Map<string, User>> {
  const users = new Map<string, User>();
  const uniqueUids = [...new Set(uids)];
  if (uniqueUids.length === 0) {
    return users;
  }
  const snapshots = await getFirestore().getAll(...uniqueUids.map(userRef));
  for (const snapshot of snapshots) {
    // getAll은 변환기 타입을 잃으므로 모델 타입으로 맞춘다.
    const user = snapshot.data() as User | undefined;
    if (user !== undefined) {
      users.set(snapshot.id, user);
    }
  }
  return users;
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
