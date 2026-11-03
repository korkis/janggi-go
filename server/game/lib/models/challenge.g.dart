// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Challenge _$ChallengeFromJson(Map<String, dynamic> json) => $checkedCreate('Challenge', json, ($checkedConvert) {
  final val = Challenge(
    fromUid: $checkedConvert('fromUid', (v) => v as String),
    from: $checkedConvert('from', (v) => RoomPlayer.fromJson(v as Map<String, dynamic>)),
    toUid: $checkedConvert('toUid', (v) => v as String),
    roomId: $checkedConvert('roomId', (v) => v as String?),
    senderSide: $checkedConvert('senderSide', (v) => $enumDecodeNullable(_$SideChoiceEnumMap, v)),
    handicap: $checkedConvert('handicap', (v) => v == null ? null : RoomHandicap.fromJson(v as Map<String, dynamic>)),
    timeControl: $checkedConvert('timeControl', (v) => TimeControl.fromJson(v as Map<String, dynamic>)),
    status: $checkedConvert('status', (v) => $enumDecode(_$ChallengeStatusEnumMap, v)),
    expiresAt: $checkedConvert('expiresAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
    gameId: $checkedConvert('gameId', (v) => v as String?),
    createdAt: $checkedConvert('createdAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
    updatedAt: $checkedConvert('updatedAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
  );
  return val;
});

Map<String, dynamic> _$ChallengeToJson(Challenge instance) => <String, dynamic>{
  'fromUid': instance.fromUid,
  'from': instance.from.toJson(),
  'toUid': instance.toUid,
  'roomId': instance.roomId,
  'senderSide': _$SideChoiceEnumMap[instance.senderSide],
  'handicap': instance.handicap?.toJson(),
  'timeControl': instance.timeControl.toJson(),
  'status': _$ChallengeStatusEnumMap[instance.status]!,
  'expiresAt': const TimestampConverter().toJson(instance.expiresAt),
  'gameId': instance.gameId,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
};

const _$SideChoiceEnumMap = {SideChoice.cho: 'cho', SideChoice.han: 'han', SideChoice.random: 'random'};

const _$ChallengeStatusEnumMap = {
  ChallengeStatus.pending: 'pending',
  ChallengeStatus.accepted: 'accepted',
  ChallengeStatus.declined: 'declined',
  ChallengeStatus.expired: 'expired',
  ChallengeStatus.cancelled: 'cancelled',
};
