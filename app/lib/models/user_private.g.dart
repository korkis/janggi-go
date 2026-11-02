// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_private.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPrivate _$UserPrivateFromJson(Map<String, dynamic> json) => UserPrivate(
  challengesEnabled: json['challengesEnabled'] as bool,
  rankProgress: (json['rankProgress'] as num).toDouble(),
  winsToNextRank: (json['winsToNextRank'] as num?)?.toInt(),
  nicknameChangeCount: (json['nicknameChangeCount'] as num).toInt(),
  nicknameChangedAt: _$JsonConverterFromJson<Timestamp, DateTime>(
    json['nicknameChangedAt'],
    const TimestampConverter().fromJson,
  ),
  sanction: json['sanction'] == null ? null : ActiveSanction.fromJson(json['sanction'] as Map<String, dynamic>),
);

Value? _$JsonConverterFromJson<Json, Value>(Object? json, Value? Function(Json json) fromJson) =>
    json == null ? null : fromJson(json as Json);

ActiveSanction _$ActiveSanctionFromJson(Map<String, dynamic> json) => ActiveSanction(
  type: $enumDecodeNullable(_$SanctionTypeEnumMap, json['type'], unknownValue: JsonKey.nullForUndefinedEnumValue),
  endsAt: _$JsonConverterFromJson<Timestamp, DateTime>(json['endsAt'], const TimestampConverter().fromJson),
  reason: json['reason'] as String,
);

const _$SanctionTypeEnumMap = {
  SanctionType.warning: 'warning',
  SanctionType.chatRestriction: 'chatRestriction',
  SanctionType.suspension: 'suspension',
  SanctionType.permanentBan: 'permanentBan',
};
