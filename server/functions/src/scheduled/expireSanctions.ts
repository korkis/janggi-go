import {onSchedule} from "firebase-functions/scheduler";
import {expireSanctions as expireSanctionsInDb} from "../services/sanctionService";

/** 한 시간마다 끝난 제재(채팅 제한, 이용 정지)를 `users_private.sanction`에서 지운다. */
export const expireSanctions = onSchedule({schedule: "every 1 hours", timeZone: "Asia/Seoul"}, async () => {
  await expireSanctionsInDb();
});
