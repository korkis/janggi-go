import {Transaction, getFirestore} from "firebase-admin/firestore";
import {Sanction} from "../models/sanction";
import {modelConverter} from "./firestore";

const COLLECTION = "sanctions";

/** 제재와 그 ID. */
export interface SanctionEntry {
  sanctionId: string;
  sanction: Sanction;
}

function sanctionsCollection() {
  return getFirestore().collection(COLLECTION).withConverter(modelConverter<Sanction>());
}

/** 제재 기록을 만들고 ID를 돌려준다. 문서 ID는 자동으로 정한다. */
export function createSanctionInTransaction(transaction: Transaction, sanction: Sanction): string {
  const ref = sanctionsCollection().doc();
  transaction.create(ref, sanction);
  return ref.id;
}

/** [uid]의 제재 이력을 최근 것부터 읽는다. 색인: `uid` + `createdAt` 내림차순(server/firestore.indexes.json). */
export async function getSanctionsByUid(uid: string, limit: number): Promise<SanctionEntry[]> {
  const snapshot = await sanctionsCollection().where("uid", "==", uid).orderBy("createdAt", "desc").limit(limit).get();
  return snapshot.docs.map((doc) => ({sanctionId: doc.id, sanction: doc.data()}));
}
