import {onSchedule} from "firebase-functions/scheduler";
import {purgeDeletedAccounts as purgeDeletedAccountsInDb} from "../services/accountService";

/** 하루 한 번 탈퇴하고 30일 지난 사람을 지운다. 사용자가 적은 새벽에 돈다. */
export const purgeDeletedAccounts = onSchedule({schedule: "every day 04:30", timeZone: "Asia/Seoul"}, async () => {
  await purgeDeletedAccountsInDb();
});
