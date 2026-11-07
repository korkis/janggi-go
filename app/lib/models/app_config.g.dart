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
  coinLossReward: (json['coinLossReward'] as num).toInt(),
  coinAttendanceReward: (json['coinAttendanceReward'] as num).toInt(),
  coinAttendanceStreakReward: (json['coinAttendanceStreakReward'] as num).toInt(),
  coinNicknameChangeCost: (json['coinNicknameChangeCost'] as num).toInt(),
  timeExtensionEnabled: json['timeExtensionEnabled'] as bool,
  gamePracticeEnabled: json['gamePracticeEnabled'] as bool,
  coinTimeExtensionCost: (json['coinTimeExtensionCost'] as num).toInt(),
  coinGamePracticeCost: (json['coinGamePracticeCost'] as num).toInt(),
  chatEnabled: json['chatEnabled'] as bool,
  signupEnabled: json['signupEnabled'] as bool,
  webEnabled: json['webEnabled'] as bool,
  coinSaleEnabled: json['coinSaleEnabled'] as bool,
  rewardedAdEnabled: json['rewardedAdEnabled'] as bool,
  bannerAdEnabled: json['bannerAdEnabled'] as bool,
  coinRewardedAdReward: (json['coinRewardedAdReward'] as num).toInt(),
  coinRewardedAdDailyLimit: (json['coinRewardedAdDailyLimit'] as num).toInt(),
  minAppVersion: json['minAppVersion'] as String,
  serviceNotice: json['serviceNotice'] == null
      ? null
      : ServiceNotice.fromJson(json['serviceNotice'] as Map<String, dynamic>),
);

ServiceNotice _$ServiceNoticeFromJson(Map<String, dynamic> json) => ServiceNotice(
  messageKo: json['messageKo'] as String,
  messageEn: json['messageEn'] as String,
  gamesBlocked: json['gamesBlocked'] as bool,
);
