// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Challenge _$ChallengeFromJson(Map<String, dynamic> json) => Challenge(
  fromUid: json['fromUid'] as String,
  from: RoomPlayer.fromJson(json['from'] as Map<String, dynamic>),
  toUid: json['toUid'] as String,
  roomId: json['roomId'] as String?,
  senderSide: $enumDecodeNullable(_$SideChoiceEnumMap, json['senderSide']),
  handicap: json['handicap'] == null ? null : RoomHandicap.fromJson(json['handicap'] as Map<String, dynamic>),
  timeControl: TimeControl.fromJson(json['timeControl'] as Map<String, dynamic>),
  status: $enumDecodeNullable(
    _$ChallengeStatusEnumMap,
    json['status'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  gameId: json['gameId'] as String?,
  expiresAt: const TimestampConverter().fromJson(json['expiresAt'] as Timestamp),
  createdAt: const TimestampConverter().fromJson(json['createdAt'] as Timestamp),
);

const _$SideChoiceEnumMap = {SideChoice.cho: 'cho', SideChoice.han: 'han', SideChoice.random: 'random'};

const _$ChallengeStatusEnumMap = {
  ChallengeStatus.pending: 'pending',
  ChallengeStatus.accepted: 'accepted',
  ChallengeStatus.declined: 'declined',
  ChallengeStatus.expired: 'expired',
  ChallengeStatus.cancelled: 'cancelled',
};
