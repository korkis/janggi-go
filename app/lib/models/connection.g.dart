// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Connection _$ConnectionFromJson(Map<String, dynamic> json) => Connection(
  online: json['online'] as bool,
  foreground: json['foreground'] as bool,
  activeSince: (json['activeSince'] as num).toInt(),
  lastSeenAt: (json['lastSeenAt'] as num).toInt(),
);
