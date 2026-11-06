import {Timestamp} from "firebase-admin/firestore";

/**
 * Firestore `coin_wallets/{uid}`. 엽전 잔액과 하루 한 번 지급 기록이다(docs/database.md). 본인만 읽고 서버만 쓴다.
 * 필드는 앱의 `CoinWallet`(app/lib/models/coin_wallet.dart), 대국 서버의 `CoinWallet`(server/game/lib/models/coin.dart)과 일치시킨다.
 */
export interface CoinWallet {
  // 받은 엽전(무상). 쓸 때 먼저 쓴다.
  freeCoins: number;
  // 산 엽전(유상). 청약철회와 환불에 대비해 나눠 기록한다.
  paidCoins: number;
  // freeCoins + paidCoins. 잔액 분포를 세기 쿼리로 보기 위해 함께 쓴다.
  balance: number;
  // 마지막으로 출석한 날(서울 기준 yyyy-MM-dd). 아직 없으면 null.
  attendanceDay: string | null;
  // 연속 출석 몇째 날인지(1~7). 7째 날 다음은 1로 돌아간다.
  attendanceStreak: number;
  updatedAt: Timestamp;
}

/**
 * 엽전이 움직인 이유. Functions와 대국 서버가 같은 값을 쓴다(docs/database.md의 공통 enum).
 * timeExtension, timeExtensionRefund, gamePractice는 대국 서버가 쓰고 Admin 웹의 지표가 센다. rewardedAd는 아직 쓰는 곳이 없다.
 */
export const CoinReason = {
  signup: "signup",
  attendance: "attendance",
  entryFee: "entryFee",
  entryFeeRefund: "entryFeeRefund",
  gameReward: "gameReward",
  nicknameChange: "nicknameChange",
  timeExtension: "timeExtension",
  timeExtensionRefund: "timeExtensionRefund",
  gamePractice: "gamePractice",
  rewardedAd: "rewardedAd",
} as const;
export type CoinReason = (typeof CoinReason)[keyof typeof CoinReason];

/** Firestore `coin_transactions/{transactionId}`. 엽전이 움직인 내역이다(서버 전용). ID는 `getCoinTransactionId`로 정한다. */
export interface CoinTransaction {
  uid: string;
  reason: CoinReason;
  // 무상 엽전 변화. 쓰면 음수다.
  freeDelta: number;
  // 유상 엽전 변화. 쓰면 음수다.
  paidDelta: number;
  // 이 움직임 뒤의 무상 잔액.
  freeBalance: number;
  // 이 움직임 뒤의 유상 잔액.
  paidBalance: number;
  // 대국과 관련된 움직임이면 그 대국.
  gameId: string | null;
  createdAt: Timestamp;
  // 탈퇴한 사용자를 지울 때 정한다. TTL 정책으로 지운다.
  expiresAt?: Timestamp;
}

/** `claimAttendance`의 결과. */
export interface ClaimAttendanceResult {
  // 이번 호출로 받았다. 오늘 이미 받았으면 false.
  granted: boolean;
  amount: number;
  // 연속 출석 몇째 날인지. 오늘 이미 받았으면 그때의 값이다.
  streak: number;
  balance: number;
}
