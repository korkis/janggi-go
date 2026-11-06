import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'coin.g.dart';

/// Firestore `coin_wallets/{uid}`. 엽전 잔액과 하루 한 번 지급 기록이다(`docs/database.md`).
///
/// 필드는 앱의 `CoinWallet`(`app/lib/models/coin_wallet.dart`), Functions의 `CoinWallet`
/// (`server/functions/src/models/coin.ts`)와 일치시킨다.
@JsonSerializable(createToJson: true)
class CoinWallet {
  /// 받은 엽전(무상). 쓸 때 먼저 쓴다.
  final int freeCoins;

  /// 산 엽전(유상).
  final int paidCoins;

  /// [freeCoins] + [paidCoins]. 잔액 분포를 세기 쿼리로 보기 위해 함께 쓴다.
  final int balance;

  /// 마지막으로 출석한 날(서울 기준 yyyy-MM-dd).
  final String? attendanceDay;

  /// 연속 출석 몇째 날인지(1~7).
  final int attendanceStreak;

  @TimestampConverter()
  final DateTime updatedAt;

  const CoinWallet({
    required this.freeCoins,
    required this.paidCoins,
    required this.balance,
    required this.attendanceDay,
    required this.attendanceStreak,
    required this.updatedAt,
  });

  factory CoinWallet.fromJson(Map<String, dynamic> json) => _$CoinWalletFromJson(json);

  Map<String, dynamic> toJson() => _$CoinWalletToJson(this);
}

/// 엽전이 움직인 이유 중 대국 서버가 쓰는 것. Functions의 `CoinReason`과 값을 일치시킨다(`docs/database.md`의 공통 enum).
enum CoinReason { entryFee, entryFeeRefund, gameReward, timeExtension, timeExtensionRefund, gamePractice }

/// Firestore `coin_transactions/{transactionId}`. 엽전이 움직인 내역이다(서버 전용).
///
/// Functions의 `CoinTransaction`(`server/functions/src/models/coin.ts`)과 필드를 일치시킨다. Functions가 쓴 다른 이유의 내역은
/// 대국 서버가 읽지 않으므로 [CoinReason]에 없어도 된다.
@JsonSerializable(createToJson: true)
class CoinTransaction {
  final String uid;
  final CoinReason reason;

  /// 무상 엽전 변화. 쓰면 음수다.
  final int freeDelta;

  /// 유상 엽전 변화. 쓰면 음수다.
  final int paidDelta;

  /// 이 움직임 뒤의 무상 잔액.
  final int freeBalance;

  /// 이 움직임 뒤의 유상 잔액.
  final int paidBalance;
  final String? gameId;

  @TimestampConverter()
  final DateTime createdAt;

  const CoinTransaction({
    required this.uid,
    required this.reason,
    required this.freeDelta,
    required this.paidDelta,
    required this.freeBalance,
    required this.paidBalance,
    required this.gameId,
    required this.createdAt,
  });

  factory CoinTransaction.fromJson(Map<String, dynamic> json) => _$CoinTransactionFromJson(json);

  Map<String, dynamic> toJson() => _$CoinTransactionToJson(this);
}
