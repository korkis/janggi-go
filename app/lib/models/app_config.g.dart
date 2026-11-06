// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => AppConfig(
  disconnectLimitSeconds: (json['disconnectLimitSeconds'] as num).toInt(),
  quickRematchLimit: (json['quickRematchLimit'] as num).toInt(),
  onlineUsersVisible: json['onlineUsersVisible'] as bool,
  autoSanctionEnabled: json['autoSanctionEnabled'] as bool,
  heartbeatSeconds: (json['heartbeatSeconds'] as num).toInt(),
  entryFeeEnabled: json['entryFeeEnabled'] as bool,
  coinSignupBonus: (json['coinSignupBonus'] as num).toInt(),
  coinEntryFee: (json['coinEntryFee'] as num).toInt(),
  coinWinReward: (json['coinWinReward'] as num).toInt(),
  coinDrawReward: (json['coinDrawReward'] as num).toInt(),
  coinLossReward: (json['coinLossReward'] as num).toInt(),
  coinAttendanceReward: (json['coinAttendanceReward'] as num).toInt(),
  coinAttendanceStreakReward: (json['coinAttendanceStreakReward'] as num).toInt(),
  coinRescueReward: (json['coinRescueReward'] as num).toInt(),
  coinRescueThreshold: (json['coinRescueThreshold'] as num).toInt(),
  coinNicknameChangeCost: (json['coinNicknameChangeCost'] as num).toInt(),
);
