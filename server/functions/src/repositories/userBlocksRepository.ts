import {getFirestore} from "firebase-admin/firestore";
import {deleteQueryDocuments} from "./firestore";

/** [uid]의 차단 목록을 지운다. */
export async function deleteUserBlocks(uid: string): Promise<void> {
  await deleteQueryDocuments(getFirestore().collection("users").doc(uid).collection("blocks"));
}
