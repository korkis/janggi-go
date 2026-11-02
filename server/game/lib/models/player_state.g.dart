// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayerState _$PlayerStateFromJson(Map<String, dynamic> json) => $checkedCreate('PlayerState', json, ($checkedConvert) {
  final val = PlayerState(
    roomId: $checkedConvert('roomId', (v) => v as String?),
    gameId: $checkedConvert('gameId', (v) => v as String?),
    lastGameId: $checkedConvert('lastGameId', (v) => v as String?),
    outgoingChallengeId: $checkedConvert('outgoingChallengeId', (v) => v as String?),
    incomingChallengeId: $checkedConvert('incomingChallengeId', (v) => v as String?),
    setupDraft: $checkedConvert('setupDraft', (v) => v == null ? null : SetupDraft.fromJson(v as Map<String, dynamic>)),
    lastRankChange: $checkedConvert(
      'lastRankChange',
      (v) => v == null ? null : RankChange.fromJson(v as Map<String, dynamic>),
    ),
    quickQueueJoinedAt: $checkedConvert(
      'quickQueueJoinedAt',
      (v) => _$JsonConverterFromJson<DateTime, DateTime>(v, const TimestampConverter().fromJson),
    ),
    updatedAt: $checkedConvert('updatedAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
  );
  return val;
});

Map<String, dynamic> _$PlayerStateToJson(PlayerState instance) => <String, dynamic>{
  'roomId': instance.roomId,
  'gameId': instance.gameId,
  'lastGameId': instance.lastGameId,
  'outgoingChallengeId': instance.outgoingChallengeId,
  'incomingChallengeId': instance.incomingChallengeId,
  'setupDraft': instance.setupDraft?.toJson(),
  'lastRankChange': instance.lastRankChange?.toJson(),
  'quickQueueJoinedAt': _$JsonConverterToJson<DateTime, DateTime>(
    instance.quickQueueJoinedAt,
    const TimestampConverter().toJson,
  ),
  'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
};

Value? _$JsonConverterFromJson<Json, Value>(Object? json, Value? Function(Json json) fromJson) =>
    json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(Value? value, Json? Function(Value value) toJson) =>
    value == null ? null : toJson(value);

SetupDraft _$SetupDraftFromJson(Map<String, dynamic> json) => $checkedCreate('SetupDraft', json, ($checkedConvert) {
  final val = SetupDraft(
    gameId: $checkedConvert('gameId', (v) => v as String),
    formation: $checkedConvert('formation', (v) => $enumDecode(_$FormationEnumMap, v)),
  );
  return val;
});

Map<String, dynamic> _$SetupDraftToJson(SetupDraft instance) => <String, dynamic>{
  'gameId': instance.gameId,
  'formation': _$FormationEnumMap[instance.formation]!,
};

const _$FormationEnumMap = {
  Formation.horseElephantHorseElephant: 'horseElephantHorseElephant',
  Formation.elephantHorseElephantHorse: 'elephantHorseElephantHorse',
  Formation.horseElephantElephantHorse: 'horseElephantElephantHorse',
  Formation.elephantHorseHorseElephant: 'elephantHorseHorseElephant',
};

RankChange _$RankChangeFromJson(Map<String, dynamic> json) => $checkedCreate('RankChange', json, ($checkedConvert) {
  final val = RankChange(
    gameId: $checkedConvert('gameId', (v) => v as String),
    rankLevelBefore: $checkedConvert('rankLevelBefore', (v) => (v as num).toInt()),
    rankLevelAfter: $checkedConvert('rankLevelAfter', (v) => (v as num).toInt()),
    rankProgressBefore: $checkedConvert('rankProgressBefore', (v) => (v as num).toDouble()),
    rankProgressAfter: $checkedConvert('rankProgressAfter', (v) => (v as num).toDouble()),
  );
  return val;
});

Map<String, dynamic> _$RankChangeToJson(RankChange instance) => <String, dynamic>{
  'gameId': instance.gameId,
  'rankLevelBefore': instance.rankLevelBefore,
  'rankLevelAfter': instance.rankLevelAfter,
  'rankProgressBefore': instance.rankProgressBefore,
  'rankProgressAfter': instance.rankProgressAfter,
};
