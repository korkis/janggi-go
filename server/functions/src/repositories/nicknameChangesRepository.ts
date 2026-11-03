import {Transaction, getFirestore} from "firebase-admin/firestore";
import {NicknameChange} from "../models/nickname";
import {modelConverter} from "./firestore";

const COLLECTION = "nickname_changes";

/** 새 기록을 만든다. 문서 ID는 자동으로 정한다. */
export function createNicknameChangeInTransaction(transaction: Transaction, change: NicknameChange): void {
  const ref = getFirestore().collection(COLLECTION).doc().withConverter(modelConverter<NicknameChange>());
  transaction.create(ref, change);
}
