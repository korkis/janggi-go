import {Transaction, getFirestore} from "firebase-admin/firestore";
import {NicknameChange} from "../models/nickname";
import {modelConverter} from "./firestore";

const COLLECTION = "nickname_changes";

/** 새 기록을 만든다. 문서 ID는 자동으로 정한다. */
export function createNicknameChangeInTransaction(transaction: Transaction, change: NicknameChange): void {
  const ref = getFirestore().collection(COLLECTION).doc().withConverter(modelConverter<NicknameChange>());
  transaction.create(ref, change);
}

/** [uid]의 닉네임 변경 기록을 최근 것부터 읽는다. 색인: `uid` + `changedAt` 내림차순(server/firestore.indexes.json). */
export async function getNicknameChangesByUid(uid: string, limit: number): Promise<NicknameChange[]> {
  const snapshot = await getFirestore()
    .collection(COLLECTION)
    .withConverter(modelConverter<NicknameChange>())
    .where("uid", "==", uid)
    .orderBy("changedAt", "desc")
    .limit(limit)
    .get();
  return snapshot.docs.map((doc) => doc.data());
}
