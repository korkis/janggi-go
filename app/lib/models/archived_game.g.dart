// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archived_game.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArchivedGame _$ArchivedGameFromJson(Map<String, dynamic> json) => ArchivedGame(
  mode: $enumDecodeNullable(_$GameModeEnumMap, json['mode'], unknownValue: JsonKey.nullForUndefinedEnumValue),
  rated: json['rated'] as bool,
  playerUids: (json['playerUids'] as List<dynamic>).map((e) => e as String).toList(),
  players: ArchivedPlayers.fromJson(json['players'] as Map<String, dynamic>),
  handicap: (json['handicap'] as List<dynamic>?)?.map((e) => $enumDecode(_$HandicapPieceEnumMap, e)).toList(),
  initialFen: json['initialFen'] as String,
  moves: (json['moves'] as List<dynamic>).map((e) => e as String).toList(),
  result: GameResultRecord.fromJson(json['result'] as Map<String, dynamic>),
  endedAt: const TimestampConverter().fromJson(json['endedAt'] as Timestamp),
);

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

ArchivedPlayers _$ArchivedPlayersFromJson(Map<String, dynamic> json) => ArchivedPlayers(
  cho: ArchivedPlayer.fromJson(json['cho'] as Map<String, dynamic>),
  han: ArchivedPlayer.fromJson(json['han'] as Map<String, dynamic>),
);

ArchivedPlayer _$ArchivedPlayerFromJson(Map<String, dynamic> json) =>
    ArchivedPlayer(uid: json['uid'] as String, rankLevel: (json['rankLevel'] as num).toInt());
