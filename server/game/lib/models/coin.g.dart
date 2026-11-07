// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CoinWallet _$CoinWalletFromJson(Map<String, dynamic> json) => $checkedCreate('CoinWallet', json, ($checkedConvert) {
  final val = CoinWallet(
    freeCoins: $checkedConvert('freeCoins', (v) => (v as num).toInt()),
    paidCoins: $checkedConvert('paidCoins', (v) => (v as num).toInt()),
    balance: $checkedConvert('balance', (v) => (v as num).toInt()),
    attendanceDay: $checkedConvert('attendanceDay', (v) => v as String?),
    attendanceStreak: $checkedConvert('attendanceStreak', (v) => (v as num).toInt()),
    rewardedAdDay: $checkedConvert('rewardedAdDay', (v) => v as String?),
    rewardedAdCount: $checkedConvert('rewardedAdCount', (v) => (v as num?)?.toInt()),
    updatedAt: $checkedConvert('updatedAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
  );
  return val;
});

Map<String, dynamic> _$CoinWalletToJson(CoinWallet instance) => <String, dynamic>{
  'freeCoins': instance.freeCoins,
  'paidCoins': instance.paidCoins,
  'balance': instance.balance,
  'attendanceDay': instance.attendanceDay,
  'attendanceStreak': instance.attendanceStreak,
  'rewardedAdDay': instance.rewardedAdDay,
  'rewardedAdCount': instance.rewardedAdCount,
  'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
};

CoinTransaction _$CoinTransactionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CoinTransaction', json, ($checkedConvert) {
      final val = CoinTransaction(
        uid: $checkedConvert('uid', (v) => v as String),
        reason: $checkedConvert('reason', (v) => $enumDecode(_$CoinReasonEnumMap, v)),
        freeDelta: $checkedConvert('freeDelta', (v) => (v as num).toInt()),
        paidDelta: $checkedConvert('paidDelta', (v) => (v as num).toInt()),
        freeBalance: $checkedConvert('freeBalance', (v) => (v as num).toInt()),
        paidBalance: $checkedConvert('paidBalance', (v) => (v as num).toInt()),
        gameId: $checkedConvert('gameId', (v) => v as String?),
        createdAt: $checkedConvert('createdAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
      );
      return val;
    });

Map<String, dynamic> _$CoinTransactionToJson(CoinTransaction instance) => <String, dynamic>{
  'uid': instance.uid,
  'reason': _$CoinReasonEnumMap[instance.reason]!,
  'freeDelta': instance.freeDelta,
  'paidDelta': instance.paidDelta,
  'freeBalance': instance.freeBalance,
  'paidBalance': instance.paidBalance,
  'gameId': instance.gameId,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
};

const _$CoinReasonEnumMap = {
  CoinReason.entryFee: 'entryFee',
  CoinReason.entryFeeRefund: 'entryFeeRefund',
  CoinReason.gameReward: 'gameReward',
  CoinReason.timeExtension: 'timeExtension',
  CoinReason.timeExtensionRefund: 'timeExtensionRefund',
  CoinReason.gamePractice: 'gamePractice',
};
