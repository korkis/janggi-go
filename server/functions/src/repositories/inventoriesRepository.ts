import {Transaction, getFirestore} from "firebase-admin/firestore";
import {Inventory} from "../models/store";
import {modelConverter} from "./firestore";

const COLLECTION = "inventories";

function inventoryRef(uid: string) {
  return getFirestore().collection(COLLECTION).doc(uid).withConverter(modelConverter<Inventory>());
}

export async function getInventoryInTransaction(transaction: Transaction, uid: string): Promise<Inventory | null> {
  const snapshot = await transaction.get(inventoryRef(uid));
  return snapshot.data() ?? null;
}

export function setInventoryInTransaction(transaction: Transaction, uid: string, inventory: Inventory): void {
  transaction.set(inventoryRef(uid), inventory);
}

export function deleteInventoryInTransaction(transaction: Transaction, uid: string): void {
  transaction.delete(inventoryRef(uid));
}
