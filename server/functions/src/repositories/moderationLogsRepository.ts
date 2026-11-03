import {FieldPath, Query, Timestamp, getFirestore} from "firebase-admin/firestore";
import {PageCursor} from "../models/admin";
import {ModerationLog} from "../models/chat";
import {modelConverter} from "./firestore";

const COLLECTION = "moderation_logs";

/** 검사 기록과 그 ID. */
export interface ModerationLogEntry {
  logId: string;
  log: ModerationLog;
}

function logsCollection() {
  return getFirestore().collection(COLLECTION).withConverter(modelConverter<ModerationLog>());
}

/** 검사에 걸린 메시지를 기록하고 기록 ID를 돌려준다. */
export async function createModerationLog(log: ModerationLog): Promise<string> {
  const logRef = logsCollection().doc();
  await logRef.create(log);
  return logRef.id;
}

/**
 * 최근 검사 기록 한 쪽. [uid]가 있으면 그 사람의 기록만 읽는다.
 * 색인: 전체는 `createdAt` 단일 필드, 사람별은 `uid` + `createdAt` 내림차순(server/firestore.indexes.json).
 */
export async function getModerationLogsPage(
  uid: string | null,
  cursor: PageCursor | null,
  limit: number,
): Promise<ModerationLogEntry[]> {
  let query: Query<ModerationLog> = logsCollection();
  if (uid !== null) {
    query = query.where("uid", "==", uid);
  }
  query = query.orderBy("createdAt", "desc").orderBy(FieldPath.documentId(), "desc");
  if (cursor !== null) {
    query = query.startAfter(Timestamp.fromMillis(cursor.afterMs), cursor.afterId);
  }
  const snapshot = await query.limit(limit).get();
  return snapshot.docs.map((doc) => ({logId: doc.id, log: doc.data()}));
}
