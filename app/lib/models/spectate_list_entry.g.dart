// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spectate_list_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpectateListEntry _$SpectateListEntryFromJson(Map<String, dynamic> json) => SpectateListEntry(
  players: SpectatePlayers.fromJson(json['players'] as Map<String, dynamic>),
  fen: json['fen'] as String,
  moveCount: (json['moveCount'] as num).toInt(),
  handicapped: json['handicapped'] as bool,
  spectatorCount: (json['spectatorCount'] as num).toInt(),
  startedAt: (json['startedAt'] as num).toInt(),
);

SpectatePlayers _$SpectatePlayersFromJson(Map<String, dynamic> json) => SpectatePlayers(
  cho: SpectatePlayer.fromJson(json['cho'] as Map<String, dynamic>),
  han: SpectatePlayer.fromJson(json['han'] as Map<String, dynamic>),
);

SpectatePlayer _$SpectatePlayerFromJson(Map<String, dynamic> json) =>
    SpectatePlayer(nickname: json['nickname'] as String, rankLevel: (json['rankLevel'] as num).toInt());
