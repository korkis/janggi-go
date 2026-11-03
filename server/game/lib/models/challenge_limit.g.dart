// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge_limit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChallengeLimit _$ChallengeLimitFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ChallengeLimit', json, ($checkedConvert) {
      final val = ChallengeLimit(
        failCount: $checkedConvert('failCount', (v) => (v as num).toInt()),
        blockedUntil: $checkedConvert(
          'blockedUntil',
          (v) => _$JsonConverterFromJson<DateTime, DateTime>(v, const TimestampConverter().fromJson),
        ),
        updatedAt: $checkedConvert('updatedAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
      );
      return val;
    });

Map<String, dynamic> _$ChallengeLimitToJson(ChallengeLimit instance) => <String, dynamic>{
  'failCount': instance.failCount,
  'blockedUntil': _$JsonConverterToJson<DateTime, DateTime>(instance.blockedUntil, const TimestampConverter().toJson),
  'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
};

Value? _$JsonConverterFromJson<Json, Value>(Object? json, Value? Function(Json json) fromJson) =>
    json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(Value? value, Json? Function(Value value) toJson) =>
    value == null ? null : toJson(value);
