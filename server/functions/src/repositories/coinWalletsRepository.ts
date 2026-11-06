import {Transaction, getFirestore} from "firebase-admin/firestore";
import {CoinWallet} from "../models/coin";
import {modelConverter} from "./firestore";

const COLLECTION = "coin_wallets";

function walletRef(uid: string) {
  return getFirestore().collection(COLLECTION).doc(uid).withConverter(modelConverter<CoinWallet>());
}

export async function getWalletInTransaction(transaction: Transaction, uid: string): Promise<CoinWallet | null> {
  const snapshot = await transaction.get(walletRef(uid));
  return snapshot.data() ?? null;
}

export function setWalletInTransaction(transaction: Transaction, uid: string, wallet: CoinWallet): void {
  transaction.set(walletRef(uid), wallet);
}

export function deleteWalletInTransaction(transaction: Transaction, uid: string): void {
  transaction.delete(walletRef(uid));
}

/** 잔액이 [min] 이상이고 [max] 미만인 지갑 수. [max]가 null이면 위를 막지 않는다. `balance` 단일 필드 색인을 쓴다. */
export async function countWalletsInBalanceRange(min: number, max: number | null): Promise<number> {
  let query = getFirestore().collection(COLLECTION).where("balance", ">=", min);
  if (max !== null) {
    query = query.where("balance", "<", max);
  }
  const snapshot = await query.count().get();
  return snapshot.data().count;
}
