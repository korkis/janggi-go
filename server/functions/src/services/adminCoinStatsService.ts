import dayjs from "dayjs";
import {Timestamp} from "firebase-admin/firestore";
import {COIN_BALANCE_BUCKET_STARTS, COIN_STATS_DAYS} from "../config";
import {CoinBalanceBucketView, CoinDayStatsView, CoinStatsView} from "../models/admin";
import {CoinReason} from "../models/coin";
import {countTransactions} from "../repositories/coinTransactionsRepository";
import {countWalletsInBalanceRange} from "../repositories/coinWalletsRepository";
import {countGamesEnded} from "../repositories/gamesArchivedRepository";
import {getCoinDay} from "./coinService";

async function getBalanceBuckets(): Promise<CoinBalanceBucketView[]> {
  return Promise.all(
    COIN_BALANCE_BUCKET_STARTS.map(async (min, index) => {
      const max = COIN_BALANCE_BUCKET_STARTS[index + 1] ?? null;
      return {min, max, count: await countWalletsInBalanceRange(min, max)};
    }),
  );
}

/** [offsetDays]일 전 하루(서울 기준)의 지표. */
async function getDayStats(offsetDays: number): Promise<CoinDayStatsView> {
  const day = getCoinDay(dayjs().subtract(offsetDays, "day"));
  // 서울 0시. `getCoinDay`의 시간대와 맞춘다.
  const start = dayjs(`${day}T00:00:00+09:00`);
  const from = Timestamp.fromMillis(start.valueOf());
  const to = Timestamp.fromMillis(start.add(1, "day").valueOf());
  const [games, timeExtensions, gamePractices, rewardedAds] = await Promise.all([
    countGamesEnded(from, to),
    countTransactions(CoinReason.timeExtension, from, to),
    countTransactions(CoinReason.gamePractice, from, to),
    countTransactions(CoinReason.rewardedAd, from, to),
  ]);
  return {day, games, timeExtensions, gamePractices, rewardedAds};
}

/** Admin 웹의 엽전 지표. 세기 쿼리만 쓴다. 날짜는 최근 것부터다. */
export async function getCoinStats(): Promise<CoinStatsView> {
  const offsets = Array.from({length: COIN_STATS_DAYS}, (_, index) => index);
  const [balanceBuckets, days] = await Promise.all([getBalanceBuckets(), Promise.all(offsets.map(getDayStats))]);
  return {balanceBuckets, days};
}
