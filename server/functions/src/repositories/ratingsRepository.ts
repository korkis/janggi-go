import {Transaction, getFirestore} from "firebase-admin/firestore";

const COLLECTION = "ratings";

/** 레이팅은 대국 서버가 쓴다. Functions는 탈퇴자를 지울 때만 닿는다. */
export function deleteRatingInTransaction(transaction: Transaction, uid: string): void {
  transaction.delete(getFirestore().collection(COLLECTION).doc(uid));
}
