// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_private.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPrivate _$UserPrivateFromJson(Map<String, dynamic> json) => $checkedCreate('UserPrivate', json, ($checkedConvert) {
  final val = UserPrivate(
    challengesEnabled: $checkedConvert('challengesEnabled', (v) => v as bool),
    rankProgress: $checkedConvert('rankProgress', (v) => (v as num).toDouble()),
    winsToNextRank: $checkedConvert('winsToNextRank', (v) => (v as num?)?.toInt()),
    nicknameChangeCount: $checkedConvert('nicknameChangeCount', (v) => (v as num).toInt()),
    nicknameChangedAt: $checkedConvert(
      'nicknameChangedAt',
      (v) => _$JsonConverterFromJson<DateTime, DateTime>(v, const TimestampConverter().fromJson),
    ),
    sanction: $checkedConvert('sanction', (v) => v == null ? null : ActiveSanction.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

Value? _$JsonConverterFromJson<Json, Value>(Object? json, Value? Function(Json json) fromJson) =>
    json == null ? null : fromJson(json as Json);

ActiveSanction _$ActiveSanctionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ActiveSanction', json, ($checkedConvert) {
      final val = ActiveSanction(
        type: $checkedConvert('type', (v) => $enumDecode(_$SanctionTypeEnumMap, v)),
        endsAt: $checkedConvert(
          'endsAt',
          (v) => _$JsonConverterFromJson<DateTime, DateTime>(v, const TimestampConverter().fromJson),
        ),
        reason: $checkedConvert('reason', (v) => v as String),
      );
      return val;
    });

const _$SanctionTypeEnumMap = {
  SanctionType.warning: 'warning',
  SanctionType.chatRestriction: 'chatRestriction',
  SanctionType.suspension: 'suspension',
  SanctionType.permanentBan: 'permanentBan',
};
