// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayerState _$PlayerStateFromJson(Map<String, dynamic> json) => PlayerState(
  roomId: json['roomId'] as String?,
  gameId: json['gameId'] as String?,
  lastGameId: json['lastGameId'] as String?,
  outgoingChallengeId: json['outgoingChallengeId'] as String?,
  incomingChallengeId: json['incomingChallengeId'] as String?,
  setupDraft: json['setupDraft'] == null ? null : SetupDraft.fromJson(json['setupDraft'] as Map<String, dynamic>),
  lastRankChange: json['lastRankChange'] == null
      ? null
      : RankChange.fromJson(json['lastRankChange'] as Map<String, dynamic>),
  gamePracticeGameId: json['gamePracticeGameId'] as String?,
  quickQueueJoinedAt: _$JsonConverterFromJson<Timestamp, DateTime>(
    json['quickQueueJoinedAt'],
    const TimestampConverter().fromJson,
  ),
  updatedAt: const TimestampConverter().fromJson(json['updatedAt'] as Timestamp),
);

Value? _$JsonConverterFromJson<Json, Value>(Object? json, Value? Function(Json json) fromJson) =>
    json == null ? null : fromJson(json as Json);

SetupDraft _$SetupDraftFromJson(Map<String, dynamic> json) =>
    SetupDraft(gameId: json['gameId'] as String, formation: $enumDecode(_$FormationEnumMap, json['formation']));

const _$FormationEnumMap = {
  Formation.horseElephantHorseElephant: 'horseElephantHorseElephant',
  Formation.elephantHorseElephantHorse: 'elephantHorseElephantHorse',
  Formation.horseElephantElephantHorse: 'horseElephantElephantHorse',
  Formation.elephantHorseHorseElephant: 'elephantHorseHorseElephant',
};

RankChange _$RankChangeFromJson(Map<String, dynamic> json) => RankChange(
  gameId: json['gameId'] as String,
  rankLevelBefore: (json['rankLevelBefore'] as num).toInt(),
  rankLevelAfter: (json['rankLevelAfter'] as num).toInt(),
  rankProgressBefore: (json['rankProgressBefore'] as num).toDouble(),
  rankProgressAfter: (json['rankProgressAfter'] as num).toDouble(),
);
