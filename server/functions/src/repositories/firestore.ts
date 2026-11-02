import {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
  Transaction,
  getFirestore,
} from "firebase-admin/firestore";

/** 문서를 모델 타입으로 그대로 읽고 쓰는 변환기. 모델은 Firestore에 저장하는 모양과 같다. */
export function modelConverter<T extends DocumentData>(): FirestoreDataConverter<T> {
  return {
    toFirestore: (model) => model,
    fromFirestore: (snapshot: QueryDocumentSnapshot) => snapshot.data() as T,
  };
}

/** service가 여러 repository의 읽기·쓰기를 한 트랜잭션으로 묶을 때 쓴다. */
export function runTransaction<T>(work: (transaction: Transaction) => Promise<T>): Promise<T> {
  return getFirestore().runTransaction(work);
}
