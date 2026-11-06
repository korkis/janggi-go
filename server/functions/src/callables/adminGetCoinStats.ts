import {onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {CoinStatsView} from "../models/admin";
import {getCoinStats} from "../services/adminCoinStatsService";
import {requireAdmin} from "./auth";

/** 엽전 지표. 잔액 분포와 최근 하루 단위의 대국 수, 시간 연장·놓아보기 사용 수, 광고 시청 수다(docs/monetization.md의 엽전). */
export const adminGetCoinStats = onCall(async (request): Promise<CoinStatsView> => {
  const adminUid = requireAdmin(request);
  const stats = await getCoinStats();
  logger.info("adminGetCoinStats 완료", {adminUid});
  return stats;
});
