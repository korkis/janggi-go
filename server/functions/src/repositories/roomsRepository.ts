import {getFirestore} from "firebase-admin/firestore";
import {deleteQueryDocuments} from "./firestore";

const COLLECTION = "rooms";

/** [uid]가 방장이었던 방을 지운다. 방은 대국 서버가 쓴다. Functions는 탈퇴자를 지울 때만 닿는다. 탈퇴하기 전에 방에서 나오므로 모두 닫힌 방이다. */
export async function deleteRoomsByHost(uid: string): Promise<void> {
  await deleteQueryDocuments(getFirestore().collection(COLLECTION).where("hostUid", "==", uid));
}
