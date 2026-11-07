import {Timestamp, Transaction, getFirestore} from "firebase-admin/firestore";
import {CoinReason, CoinTransaction} from "../models/coin";
import {modelConverter, updateQueryDocuments} from "./firestore";

const COLLECTION = "coin_transactions";

function transactionRef(transactionId: string) {
  return getFirestore().collection(COLLECTION).doc(transactionId).withConverter(modelConverter<CoinTransaction>());
}

/**
 * 내역 문서 ID. 이유, uid, 한 번만 일어나는 일의 열쇠(대국 ID, 날짜, 횟수)로 정해 같은 일이 두 번 쓰이지 않게 한다.
 * 대국 서버의 `getCoinTransactionId`(server/game/lib/services/coin_rules.dart)와 같은 모양이다.
 */
export function getCoinTransactionId(reason: CoinReason, uid: string, key: string | null): string {
  return key === null ? `${reason}_${uid}` : `${reason}_${uid}_${key}`;
}

/** 이 ID의 내역이 있는지. 같은 일이 다시 왔을 때 오류 없이 넘어가려고 쓴다. */
export async function hasCoinTransactionInTransaction(transaction: Transaction, transactionId: string): Promise<boolean> {
  return (await transaction.get(transactionRef(transactionId))).exists;
}

/** 내역을 만든다. 같은 ID가 이미 있으면 커밋이 실패해 지갑도 바뀌지 않는다. */
export function createCoinTransactionInTransaction(
  transaction: Transaction,
  transactionId: string,
  coinTransaction: CoinTransaction,
): void {
  transaction.create(transactionRef(transactionId), coinTransaction);
}

/** [uid]의 내역에 [expiresAt]을 쓴다. TTL 정책으로 지운다(docs/database.md의 회원 탈퇴). */
export async function setCoinTransactionsExpiry(uid: string, expiresAt: Timestamp): Promise<void> {
  await updateQueryDocuments(getFirestore().collection(COLLECTION).where("uid", "==", uid), {expiresAt});
}

/** [from] 이상 [to] 미만에 일어난 [reason] 내역 수. `reason` + `createdAt` 색인을 쓴다. */
export async function countTransactions(reason: CoinReason, from: Timestamp, to: Timestamp): Promise<number> {
  const snapshot = await getFirestore()
    .collection(COLLECTION)
    .where("reason", "==", reason)
    .where("createdAt", ">=", from)
    .where("createdAt", "<", to)
    .count()
    .get();
  return snapshot.data().count;
}
