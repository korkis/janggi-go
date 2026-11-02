// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => $checkedCreate('User', json, ($checkedConvert) {
  final val = User(
    nickname: $checkedConvert('nickname', (v) => v as String),
    rankLevel: $checkedConvert('rankLevel', (v) => (v as num).toInt()),
    stats: $checkedConvert('stats', (v) => UserStats.fromJson(v as Map<String, dynamic>)),
    createdAt: $checkedConvert('createdAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
  );
  return val;
});

UserStats _$UserStatsFromJson(Map<String, dynamic> json) => $checkedCreate('UserStats', json, ($checkedConvert) {
  final val = UserStats(
    games: $checkedConvert('games', (v) => (v as num).toInt()),
    wins: $checkedConvert('wins', (v) => (v as num).toInt()),
    losses: $checkedConvert('losses', (v) => (v as num).toInt()),
  );
  return val;
});
