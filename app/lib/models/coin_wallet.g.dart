// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coin_wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CoinWallet _$CoinWalletFromJson(Map<String, dynamic> json) => CoinWallet(
  freeCoins: (json['freeCoins'] as num).toInt(),
  paidCoins: (json['paidCoins'] as num).toInt(),
  balance: (json['balance'] as num).toInt(),
  attendanceDay: json['attendanceDay'] as String?,
  attendanceStreak: (json['attendanceStreak'] as num).toInt(),
  rescueDay: json['rescueDay'] as String?,
  updatedAt: const TimestampConverter().fromJson(json['updatedAt'] as Timestamp),
);
