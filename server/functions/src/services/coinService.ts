import dayjs, {Dayjs} from "dayjs";
import {Timestamp, Transaction} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {COIN_ATTENDANCE_STREAK_DAYS, COIN_DAY_UTC_OFFSET_HOURS} from "../config";
import {ClaimAttendanceResult, CoinReason, CoinWallet} from "../models/coin";
import {NicknameChangeErrorCode} from "../models/nickname";
import {createCoinTransactionInTransaction, getCoinTransactionId} from "../repositories/coinTransactionsRepository";
import {getWalletInTransaction, setWalletInTransaction} from "../repositories/coinWalletsRepository";
import {getAppConfig} from "../repositories/configsRepository";
import {runTransaction} from "../repositories/firestore";

/** 엽전을 움직이는 한 번의 일. 어떤 지갑이 어떻게 바뀌었는지 내역에 남긴다. */
interface CoinMove {
  uid: string;
  reason: CoinReason;
  // 한 번만 일어나는 일의 열쇠. 내역 ID에 들어간다(getCoinTransactionId).
  key: string | null;
  freeDelta: number;
  paidDelta: number;
}

/** 하루의 기준. 서울 시간 0시에 바뀌는 yyyy-MM-dd다(docs/monetization.md의 엽전). */
export function getCoinDay(time: Dayjs): string {
  return time.add(COIN_DAY_UTC_OFFSET_HOURS, "hour").toISOString().slice(0, 10);
}

/** [wallet]에서 [cost]를 쓸 때 무상과 유상에서 나갈 양(음수). 무상부터 쓴다(docs/monetization.md의 지킬 선). */
function getSpendDeltas(wallet: CoinWallet, cost: number): {freeDelta: number; paidDelta: number} {
  const fromFree = Math.min(wallet.freeCoins, cost);
  return {freeDelta: -fromFree, paidDelta: -(cost - fromFree)};
}

/** [move]를 [wallet]에 더한 지갑을 쓰고 내역을 만든다. 바뀐 지갑을 돌려준다. 호출하기 전에 읽기를 모두 끝낸다. */
function applyMoveInTransaction(
  transaction: Transaction,
  wallet: CoinWallet,
  move: CoinMove,
  now: Timestamp,
  walletChanges: Partial<CoinWallet> = {},
): CoinWallet {
  const freeCoins = wallet.freeCoins + move.freeDelta;
  const paidCoins = wallet.paidCoins + move.paidDelta;
  const next: CoinWallet = {
    ...wallet,
    ...walletChanges,
    freeCoins,
    paidCoins,
    balance: freeCoins + paidCoins,
    updatedAt: now,
  };
  setWalletInTransaction(transaction, move.uid, next);
  createCoinTransactionInTransaction(transaction, getCoinTransactionId(move.reason, move.uid, move.key), {
    uid: move.uid,
    reason: move.reason,
    freeDelta: move.freeDelta,
    paidDelta: move.paidDelta,
    freeBalance: freeCoins,
    paidBalance: paidCoins,
    gameId: null,
    createdAt: now,
  });
  return next;
}

/** 지갑을 만들고 가입 지급을 프로필과 같은 트랜잭션에 넣는다. 프로필을 처음 만들 때만 부른다. 호출하기 전에 읽기를 모두 끝낸다. */
export function grantSignupInTransaction(transaction: Transaction, uid: string, amount: number, now: Timestamp): void {
  const wallet: CoinWallet = {
    freeCoins: 0,
    paidCoins: 0,
    balance: 0,
    attendanceDay: null,
    attendanceStreak: 0,
    updatedAt: now,
  };
  applyMoveInTransaction(
    transaction,
    wallet,
    {uid, reason: CoinReason.signup, key: null, freeDelta: amount, paidDelta: 0},
    now,
  );
}

/** 닉네임 변경 값을 내게 한다. [changeCount]번째 변경 값이 두 번 나가지 않는다. 호출하기 전에 읽기를 모두 끝낸다. */
export function spendNicknameChangeInTransaction(
  transaction: Transaction,
  uid: string,
  wallet: CoinWallet,
  cost: number,
  changeCount: number,
  now: Timestamp,
): void {
  if (wallet.balance < cost) {
    throw new HttpsError("failed-precondition", "엽전이 모자랍니다", {code: NicknameChangeErrorCode.coinsInsufficient});
  }
  applyMoveInTransaction(
    transaction,
    wallet,
    {uid, reason: CoinReason.nicknameChange, key: String(changeCount), ...getSpendDeltas(wallet, cost)},
    now,
  );
}

/**
 * 오늘의 출석을 준다. 연속 7째 날은 평소 값 대신 그 날의 값을 주고 다음 날 1로 돌아간다. 하루가 비면 1부터 다시 센다.
 * 오늘 이미 받았으면 아무것도 바꾸지 않고 granted false를 돌려주므로 여러 번 불려도 한 번만 받는다.
 * 지갑은 프로필과 함께 만들므로 지갑이 없으면 닉네임을 아직 정하지 않은 것이다.
 */
export async function claimAttendance(uid: string): Promise<ClaimAttendanceResult> {
  const config = await getAppConfig();
  const result = await runTransaction(async (transaction): Promise<ClaimAttendanceResult> => {
    const wallet = await getWalletInTransaction(transaction, uid);
    if (wallet === null) {
      throw new HttpsError("failed-precondition", "닉네임을 먼저 정해야 합니다", {code: "profileRequired"});
    }
    const time = dayjs();
    const today = getCoinDay(time);
    if (wallet.attendanceDay === today) {
      return {granted: false, amount: 0, streak: wallet.attendanceStreak, balance: wallet.balance};
    }
    const continued =
      wallet.attendanceDay === getCoinDay(time.subtract(1, "day")) &&
      wallet.attendanceStreak < COIN_ATTENDANCE_STREAK_DAYS;
    const streak = continued ? wallet.attendanceStreak + 1 : 1;
    const amount =
      streak === COIN_ATTENDANCE_STREAK_DAYS ? config.coinAttendanceStreakReward : config.coinAttendanceReward;
    const next = applyMoveInTransaction(
      transaction,
      wallet,
      {uid, reason: CoinReason.attendance, key: today, freeDelta: amount, paidDelta: 0},
      Timestamp.fromMillis(time.valueOf()),
      {attendanceDay: today, attendanceStreak: streak},
    );
    return {granted: true, amount, streak, balance: next.balance};
  });
  logger.info("claimAttendance 완료", {uid, ...result});
  return result;
}
