import {getFirestore} from "firebase-admin/firestore";
import {ModerationLog} from "../models/chat";
import {modelConverter} from "./firestore";

const COLLECTION = "moderation_logs";

/** 검사에 걸린 메시지를 기록하고 기록 ID를 돌려준다. */
export async function createModerationLog(log: ModerationLog): Promise<string> {
  const logRef = getFirestore().collection(COLLECTION).withConverter(modelConverter<ModerationLog>()).doc();
  await logRef.create(log);
  return logRef.id;
}
