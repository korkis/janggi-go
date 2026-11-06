import {Transaction, getFirestore} from "firebase-admin/firestore";
import {DeletedAccount} from "../models/account";
import {modelConverter} from "./firestore";

const COLLECTION = "deleted_accounts";

function deletedAccountRef(identityHash: string) {
  return getFirestore().collection(COLLECTION).doc(identityHash).withConverter(modelConverter<DeletedAccount>());
}

export async function setDeletedAccount(identityHash: string, deletedAccount: DeletedAccount): Promise<void> {
  await deletedAccountRef(identityHash).set(deletedAccount);
}

export async function getDeletedAccountInTransaction(
  transaction: Transaction,
  identityHash: string,
): Promise<DeletedAccount | null> {
  const snapshot = await transaction.get(deletedAccountRef(identityHash));
  return snapshot.data() ?? null;
}
