// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'online_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnlineUser _$OnlineUserFromJson(Map<String, dynamic> json) => OnlineUser(
  nickname: json['nickname'] as String,
  rankLevel: (json['rankLevel'] as num).toInt(),
  status: $enumDecodeNullable(_$OnlineStatusEnumMap, json['status'], unknownValue: JsonKey.nullForUndefinedEnumValue),
  challengesEnabled: json['challengesEnabled'] as bool,
  since: (json['since'] as num).toInt(),
);

const _$OnlineStatusEnumMap = {OnlineStatus.waiting: 'waiting', OnlineStatus.playing: 'playing'};
