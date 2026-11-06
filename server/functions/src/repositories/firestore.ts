import {
  DocumentData,
  FirestoreDataConverter,
  Query,
  QueryDocumentSnapshot,
  Transaction,
  UpdateData,
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

/** [query]에 걸리는 문서를 모두 지운다. */
export async function deleteQueryDocuments(query: Query): Promise<void> {
  const snapshot = await query.select().get();
  const writer = getFirestore().bulkWriter();
  for (const doc of snapshot.docs) {
    void writer.delete(doc.ref);
  }
  await writer.close();
}

/** [query]에 걸리는 문서를 모두 [data]로 고친다. */
export async function updateQueryDocuments(query: Query, data: UpdateData<object>): Promise<void> {
  const snapshot = await query.select().get();
  const writer = getFirestore().bulkWriter();
  for (const doc of snapshot.docs) {
    void writer.update(doc.ref, data);
  }
  await writer.close();
}
