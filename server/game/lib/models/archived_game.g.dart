// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archived_game.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArchivedGame _$ArchivedGameFromJson(Map<String, dynamic> json) => $checkedCreate('ArchivedGame', json, (
  $checkedConvert,
) {
  final val = ArchivedGame(
    mode: $checkedConvert('mode', (v) => $enumDecode(_$GameModeEnumMap, v)),
    rated: $checkedConvert('rated', (v) => v as bool),
    roomId: $checkedConvert('roomId', (v) => v as String?),
    playerUids: $checkedConvert('playerUids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
    pairKey: $checkedConvert('pairKey', (v) => v as String),
    players: $checkedConvert('players', (v) => ArchivedPlayers.fromJson(v as Map<String, dynamic>)),
    handicap: $checkedConvert(
      'handicap',
      (v) => (v as List<dynamic>?)?.map((e) => $enumDecode(_$HandicapPieceEnumMap, e)).toList(),
    ),
    timeControl: $checkedConvert('timeControl', (v) => TimeControl.fromJson(v as Map<String, dynamic>)),
    initialFen: $checkedConvert('initialFen', (v) => v as String),
    moves: $checkedConvert('moves', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
    moveTimesMs: $checkedConvert('moveTimesMs', (v) => (v as List<dynamic>).map((e) => (e as num).toInt()).toList()),
    result: $checkedConvert('result', (v) => GameResultRecord.fromJson(v as Map<String, dynamic>)),
    rematchOf: $checkedConvert('rematchOf', (v) => v as String?),
    startedAt: $checkedConvert('startedAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
    endedAt: $checkedConvert('endedAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
  );
  return val;
});

Map<String, dynamic> _$ArchivedGameToJson(ArchivedGame instance) => <String, dynamic>{
  'mode': _$GameModeEnumMap[instance.mode]!,
  'rated': instance.rated,
  'roomId': instance.roomId,
  'playerUids': instance.playerUids,
  'pairKey': instance.pairKey,
  'players': instance.players.toJson(),
  'handicap': instance.handicap?.map((e) => _$HandicapPieceEnumMap[e]!).toList(),
  'timeControl': instance.timeControl.toJson(),
  'initialFen': instance.initialFen,
  'moves': instance.moves,
  'moveTimesMs': instance.moveTimesMs,
  'result': instance.result.toJson(),
  'rematchOf': instance.rematchOf,
  'startedAt': const TimestampConverter().toJson(instance.startedAt),
  'endedAt': const TimestampConverter().toJson(instance.endedAt),
};

const _$GameModeEnumMap = {GameMode.quick: 'quick', GameMode.room: 'room', GameMode.challenge: 'challenge'};

const _$HandicapPieceEnumMap = {
  HandicapPiece.leftChariot: 'leftChariot',
  HandicapPiece.rightChariot: 'rightChariot',
  HandicapPiece.leftCannon: 'leftCannon',
  HandicapPiece.rightCannon: 'rightCannon',
  HandicapPiece.leftHorse: 'leftHorse',
  HandicapPiece.rightHorse: 'rightHorse',
  HandicapPiece.leftElephant: 'leftElephant',
  HandicapPiece.rightElephant: 'rightElephant',
};

ArchivedPlayers _$ArchivedPlayersFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ArchivedPlayers', json, ($checkedConvert) {
      final val = ArchivedPlayers(
        cho: $checkedConvert('cho', (v) => ArchivedPlayer.fromJson(v as Map<String, dynamic>)),
        han: $checkedConvert('han', (v) => ArchivedPlayer.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    });

Map<String, dynamic> _$ArchivedPlayersToJson(ArchivedPlayers instance) => <String, dynamic>{
  'cho': instance.cho.toJson(),
  'han': instance.han.toJson(),
};

ArchivedPlayer _$ArchivedPlayerFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ArchivedPlayer', json, ($checkedConvert) {
      final val = ArchivedPlayer(
        uid: $checkedConvert('uid', (v) => v as String),
        rankLevel: $checkedConvert('rankLevel', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$ArchivedPlayerToJson(ArchivedPlayer instance) => <String, dynamic>{
  'uid': instance.uid,
  'rankLevel': instance.rankLevel,
};
