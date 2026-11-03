import {onSchedule} from "firebase-functions/scheduler";
import {cleanupChats as cleanupChatsInDb} from "../services/chatCleanupService";

/** 하루 한 번 보관 기간(90일)이 지난 RTDB 채팅을 지운다. 사용자가 적은 새벽에 돈다. */
export const cleanupChats = onSchedule({schedule: "every day 04:00", timeZone: "Asia/Seoul"}, async () => {
  await cleanupChatsInDb();
});
