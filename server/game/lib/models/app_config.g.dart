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
    coinLossReward: $checkedConvert('coinLossReward', (v) => (v as num).toInt()),
    coinAttendanceReward: $checkedConvert('coinAttendanceReward', (v) => (v as num).toInt()),
    coinAttendanceStreakReward: $checkedConvert('coinAttendanceStreakReward', (v) => (v as num).toInt()),
    coinNicknameChangeCost: $checkedConvert('coinNicknameChangeCost', (v) => (v as num).toInt()),
    timeExtensionEnabled: $checkedConvert('timeExtensionEnabled', (v) => v as bool),
    gamePracticeEnabled: $checkedConvert('gamePracticeEnabled', (v) => v as bool),
    coinTimeExtensionCost: $checkedConvert('coinTimeExtensionCost', (v) => (v as num).toInt()),
    coinGamePracticeCost: $checkedConvert('coinGamePracticeCost', (v) => (v as num).toInt()),
    chatEnabled: $checkedConvert('chatEnabled', (v) => v as bool),
    signupEnabled: $checkedConvert('signupEnabled', (v) => v as bool),
    webEnabled: $checkedConvert('webEnabled', (v) => v as bool),
    coinSaleEnabled: $checkedConvert('coinSaleEnabled', (v) => v as bool),
    minAppVersion: $checkedConvert('minAppVersion', (v) => v as String),
    serviceNotice: $checkedConvert(
      'serviceNotice',
      (v) => v == null ? null : ServiceNotice.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

ServiceNotice _$ServiceNoticeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ServiceNotice', json, ($checkedConvert) {
      final val = ServiceNotice(
        messageKo: $checkedConvert('messageKo', (v) => v as String),
        messageEn: $checkedConvert('messageEn', (v) => v as String),
        gamesBlocked: $checkedConvert('gamesBlocked', (v) => v as bool),
      );
      return val;
    });
