import {defineSecret} from "firebase-functions/params";
import {onSchedule} from "firebase-functions/scheduler";
import {purgeDeletedAccounts as purgeDeletedAccountsInDb} from "../services/accountService";

// RevenueCat 비밀 API 키. 탈퇴자의 RevenueCat 고객을 지울 때 쓴다. Secret Manager에 두고, 에뮬레이터는 server/functions/.secret.local에서 읽는다.
const revenueCatSecretApiKey = defineSecret("REVENUECAT_SECRET_API_KEY");

/** 하루 한 번 탈퇴하고 30일 지난 사람을 지운다. 사용자가 적은 새벽에 돈다. */
export const purgeDeletedAccounts = onSchedule(
  {schedule: "every day 04:30", timeZone: "Asia/Seoul", secrets: [revenueCatSecretApiKey]},
  async () => {
    await purgeDeletedAccountsInDb(revenueCatSecretApiKey.value());
  },
);
