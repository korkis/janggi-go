// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spectate_list_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpectateListEntry _$SpectateListEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SpectateListEntry', json, ($checkedConvert) {
      final val = SpectateListEntry(
        players: $checkedConvert('players', (v) => SpectatePlayers.fromJson(v as Map<String, dynamic>)),
        fen: $checkedConvert('fen', (v) => v as String),
        moveCount: $checkedConvert('moveCount', (v) => (v as num).toInt()),
        handicapped: $checkedConvert('handicapped', (v) => v as bool),
        spectatorCount: $checkedConvert('spectatorCount', (v) => (v as num).toInt()),
        startedAt: $checkedConvert('startedAt', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$SpectateListEntryToJson(SpectateListEntry instance) => <String, dynamic>{
  'players': instance.players.toJson(),
  'fen': instance.fen,
  'moveCount': instance.moveCount,
  'handicapped': instance.handicapped,
  'spectatorCount': instance.spectatorCount,
  'startedAt': instance.startedAt,
};

SpectatePlayers _$SpectatePlayersFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SpectatePlayers', json, ($checkedConvert) {
      final val = SpectatePlayers(
        cho: $checkedConvert('cho', (v) => SpectatePlayer.fromJson(v as Map<String, dynamic>)),
        han: $checkedConvert('han', (v) => SpectatePlayer.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    });

Map<String, dynamic> _$SpectatePlayersToJson(SpectatePlayers instance) => <String, dynamic>{
  'cho': instance.cho.toJson(),
  'han': instance.han.toJson(),
};

SpectatePlayer _$SpectatePlayerFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SpectatePlayer', json, ($checkedConvert) {
      final val = SpectatePlayer(
        nickname: $checkedConvert('nickname', (v) => v as String),
        rankLevel: $checkedConvert('rankLevel', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$SpectatePlayerToJson(SpectatePlayer instance) => <String, dynamic>{
  'nickname': instance.nickname,
  'rankLevel': instance.rankLevel,
};
