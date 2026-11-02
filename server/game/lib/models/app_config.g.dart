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
  );
  return val;
});
