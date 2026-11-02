// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Connection _$ConnectionFromJson(Map<String, dynamic> json) => $checkedCreate('Connection', json, ($checkedConvert) {
  final val = Connection(
    online: $checkedConvert('online', (v) => v as bool),
    foreground: $checkedConvert('foreground', (v) => v as bool),
    activeSince: $checkedConvert('activeSince', (v) => (v as num).toInt()),
    lastSeenAt: $checkedConvert('lastSeenAt', (v) => (v as num).toInt()),
  );
  return val;
});
