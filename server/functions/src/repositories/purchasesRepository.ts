import {Timestamp, Transaction, getFirestore} from "firebase-admin/firestore";
import {Purchase, PurchaseStatus} from "../models/store";
import {modelConverter, updateQueryDocuments} from "./firestore";

const COLLECTION = "purchases";

function purchaseRef(purchaseId: string) {
  return getFirestore().collection(COLLECTION).doc(purchaseId).withConverter(modelConverter<Purchase>());
}

/** 구매 문서 ID. 영수증 번호에 문서 ID로 쓸 수 없는 글자가 있어도 되도록 인코딩한다. */
export function getPurchaseId(store: string, transactionId: string): string {
  return `${store}_${encodeURIComponent(transactionId)}`;
}

export async function getPurchaseInTransaction(transaction: Transaction, purchaseId: string): Promise<Purchase | null> {
  const snapshot = await transaction.get(purchaseRef(purchaseId));
  return snapshot.data() ?? null;
}

/** 구매를 기록한다. 같은 영수증이 이미 있으면 커밋이 실패해 지급도 되지 않는다. */
export function createPurchaseInTransaction(transaction: Transaction, purchaseId: string, purchase: Purchase): void {
  transaction.create(purchaseRef(purchaseId), purchase);
}

export function markPurchaseRefundedInTransaction(transaction: Transaction, purchaseId: string, now: Timestamp): void {
  transaction.update(purchaseRef(purchaseId), {status: PurchaseStatus.refunded, refundedAt: now});
}

/** [uid]가 [productId]를 산 기록 중 환불되지 않은 것이 [exceptPurchaseId] 말고 또 있는지. 두 스토어에서 같은 상품을 산 경우를 가린다. */
export async function hasOtherGrantedPurchaseInTransaction(
  transaction: Transaction,
  uid: string,
  productId: string,
  exceptPurchaseId: string,
): Promise<boolean> {
  const snapshot = await transaction.get(
    getFirestore()
      .collection(COLLECTION)
      .where("uid", "==", uid)
      .where("productId", "==", productId)
      .where("status", "==", PurchaseStatus.granted),
  );
  return snapshot.docs.some((document) => document.id !== exceptPurchaseId);
}

/** [uid]의 구매 기록에 [expiresAt]을 쓴다. TTL 정책으로 지운다(docs/database.md의 회원 탈퇴). */
export async function setPurchasesExpiry(uid: string, expiresAt: Timestamp): Promise<void> {
  await updateQueryDocuments(getFirestore().collection(COLLECTION).where("uid", "==", uid), {expiresAt});
}
