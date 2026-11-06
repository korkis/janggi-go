import {Timestamp, getFirestore} from "firebase-admin/firestore";

const COLLECTION = "games_archived";

/** [from] 이상 [to] 미만에 끝난 대국 수. `endedAt` 단일 필드 색인을 쓴다. 기보는 대국 서버가 쓰고 Functions는 세기만 한다. */
export async function countGamesEnded(from: Timestamp, to: Timestamp): Promise<number> {
  const snapshot = await getFirestore()
    .collection(COLLECTION)
    .where("endedAt", ">=", from)
    .where("endedAt", "<", to)
    .count()
    .get();
  return snapshot.data().count;
}
