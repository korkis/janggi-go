import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'coin_wallet.g.dart';

/// Firestore `coin_wallets/{uid}`. 엽전 잔액이다(`docs/database.md`). 본인만 읽고 서버만 쓴다.
///
/// 필드는 대국 서버의 `CoinWallet`(`server/game/lib/models/coin.dart`), Functions의 `CoinWallet`
/// (`server/functions/src/models/coin.ts`)와 일치시킨다.
@JsonSerializable(createToJson: false)
class CoinWallet {
  /// 받은 엽전(무상). 쓸 때 먼저 쓴다.
  final int freeCoins;

  /// 산 엽전(유상).
  final int paidCoins;

  /// [freeCoins] + [paidCoins].
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
}

/// `claimAttendance`의 결과.
class AttendanceResult {
  /// 이번 호출로 받았다. 오늘 이미 받았으면 false.
  final bool granted;
  final int amount;

  const AttendanceResult({required this.granted, required this.amount});
}
