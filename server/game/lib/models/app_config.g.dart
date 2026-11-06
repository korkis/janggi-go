// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => $checkedCreate('AppConfig', json, ($checkedConvert) {
  final val = AppConfig(
    disconnectLimitSeconds: $checkedConvert('disconnectLimitSeconds', (v) => (v as num).toInt()),
    quickRematchLimit: $checkedConvert('quickRematchLimit', (v) => (v as num).toInt()),
    onlineUsersVisible: $checkedConvert('onlineUsersVisible', (v) => v as bool),
    autoSanctionEnabled: $checkedConvert('autoSanctionEnabled', (v) => v as bool),
    heartbeatSeconds: $checkedConvert('heartbeatSeconds', (v) => (v as num).toInt()),
    entryFeeEnabled: $checkedConvert('entryFeeEnabled', (v) => v as bool),
    coinSignupBonus: $checkedConvert('coinSignupBonus', (v) => (v as num).toInt()),
    coinEntryFee: $checkedConvert('coinEntryFee', (v) => (v as num).toInt()),
    coinWinReward: $checkedConvert('coinWinReward', (v) => (v as num).toInt()),
    coinDrawReward: $checkedConvert('coinDrawReward', (v) => (v as num).toInt()),
    coinLossReward: $checkedConvert('coinLossReward', (v) => (v as num).toInt()),
    coinAttendanceReward: $checkedConvert('coinAttendanceReward', (v) => (v as num).toInt()),
    coinAttendanceStreakReward: $checkedConvert('coinAttendanceStreakReward', (v) => (v as num).toInt()),
    coinRescueReward: $checkedConvert('coinRescueReward', (v) => (v as num).toInt()),
    coinRescueThreshold: $checkedConvert('coinRescueThreshold', (v) => (v as num).toInt()),
    coinNicknameChangeCost: $checkedConvert('coinNicknameChangeCost', (v) => (v as num).toInt()),
  );
  return val;
});
