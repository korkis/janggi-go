import {getFirestore} from "firebase-admin/firestore";
import {deleteQueryDocuments} from "./firestore";

const COLLECTION = "challenges";

/** [uid]가 보내거나 받은 신청을 지운다. 신청은 대국 서버가 쓴다. Functions는 탈퇴자를 지울 때만 닿는다. */
export async function deleteChallengesByUid(uid: string): Promise<void> {
  const challenges = getFirestore().collection(COLLECTION);
  await Promise.all([
    deleteQueryDocuments(challenges.where("fromUid", "==", uid)),
    deleteQueryDocuments(challenges.where("toUid", "==", uid)),
  ]);
}
