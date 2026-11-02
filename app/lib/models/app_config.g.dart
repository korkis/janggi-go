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
);
