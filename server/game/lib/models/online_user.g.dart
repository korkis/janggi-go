// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'online_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnlineUser _$OnlineUserFromJson(Map<String, dynamic> json) => $checkedCreate('OnlineUser', json, ($checkedConvert) {
  final val = OnlineUser(
    nickname: $checkedConvert('nickname', (v) => v as String),
    rankLevel: $checkedConvert('rankLevel', (v) => (v as num).toInt()),
    status: $checkedConvert('status', (v) => $enumDecode(_$OnlineStatusEnumMap, v)),
    challengesEnabled: $checkedConvert('challengesEnabled', (v) => v as bool),
    since: $checkedConvert('since', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$OnlineUserToJson(OnlineUser instance) => <String, dynamic>{
  'nickname': instance.nickname,
  'rankLevel': instance.rankLevel,
  'status': _$OnlineStatusEnumMap[instance.status]!,
  'challengesEnabled': instance.challengesEnabled,
  'since': instance.since,
};

const _$OnlineStatusEnumMap = {OnlineStatus.waiting: 'waiting', OnlineStatus.playing: 'playing'};
