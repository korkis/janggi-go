// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_game.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActiveGame _$ActiveGameFromJson(Map<String, dynamic> json) => ActiveGame(
  meta: GameMeta.fromJson(json['meta'] as Map<String, dynamic>),
  state: GameState.fromJson(json['state'] as Map<String, dynamic>),
  moves:
      (json['moves'] as List<dynamic>?)?.map((e) => GameMoveRecord.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  rematch: json['rematch'] == null ? null : GameRematch.fromJson(json['rematch'] as Map<String, dynamic>),
);

GameMeta _$GameMetaFromJson(Map<String, dynamic> json) => GameMeta(
  mode: $enumDecodeNullable(_$GameModeEnumMap, json['mode'], unknownValue: JsonKey.nullForUndefinedEnumValue),
  rated: json['rated'] as bool,
  roomId: json['roomId'] as String?,
  listed: json['listed'] as bool,
  players: GamePlayers.fromJson(json['players'] as Map<String, dynamic>),
  handicap: (json['handicap'] as List<dynamic>?)?.map((e) => $enumDecode(_$HandicapPieceEnumMap, e)).toList(),
  timeControl: TimeControl.fromJson(json['timeControl'] as Map<String, dynamic>),
  disconnectLimitMs: (json['disconnectLimitMs'] as num).toInt(),
  rematchOf: json['rematchOf'] as String?,
  rematchCount: (json['rematchCount'] as num).toInt(),
  createdAt: (json['createdAt'] as num).toInt(),
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

GamePlayers _$GamePlayersFromJson(Map<String, dynamic> json) => GamePlayers(
  cho: GamePlayer.fromJson(json['cho'] as Map<String, dynamic>),
  han: GamePlayer.fromJson(json['han'] as Map<String, dynamic>),
);

GamePlayer _$GamePlayerFromJson(Map<String, dynamic> json) => GamePlayer(
  uid: json['uid'] as String,
  nickname: json['nickname'] as String,
  rankLevel: (json['rankLevel'] as num).toInt(),
  pieceMaterial: $enumDecodeNullable(
    _$PieceMaterialEnumMap,
    json['pieceMaterial'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
);

const _$PieceMaterialEnumMap = {
  PieceMaterial.plastic: 'plastic',
  PieceMaterial.wood: 'wood',
  PieceMaterial.aluminum: 'aluminum',
};

TimeControl _$TimeControlFromJson(Map<String, dynamic> json) => TimeControl(
  baseMs: (json['baseMs'] as num).toInt(),
  periodMs: (json['periodMs'] as num).toInt(),
  periods: (json['periods'] as num).toInt(),
  setupMs: (json['setupMs'] as num).toInt(),
  extensionPeriods: (json['extensionPeriods'] as num).toInt(),
  extensionLimit: (json['extensionLimit'] as num).toInt(),
);

GameState _$GameStateFromJson(Map<String, dynamic> json) => GameState(
  version: (json['version'] as num).toInt(),
  phase: $enumDecode(_$GamePhaseEnumMap, json['phase']),
  setup: GameSetup.fromJson(json['setup'] as Map<String, dynamic>),
  initialFen: json['initialFen'] as String?,
  turn: $enumDecodeNullable(_$SideEnumMap, json['turn']),
  turnStartedAt: (json['turnStartedAt'] as num?)?.toInt(),
  clock: SideClocks.fromJson(json['clock'] as Map<String, dynamic>),
  disconnect: SideDisconnects.fromJson(json['disconnect'] as Map<String, dynamic>),
  extensionNotice: json['extensionNotice'] == null
      ? null
      : ExtensionNotice.fromJson(json['extensionNotice'] as Map<String, dynamic>),
  result: json['result'] == null ? null : GameResultRecord.fromJson(json['result'] as Map<String, dynamic>),
  endedAt: (json['endedAt'] as num?)?.toInt(),
);

const _$GamePhaseEnumMap = {GamePhase.setup: 'setup', GamePhase.playing: 'playing', GamePhase.finished: 'finished'};

const _$SideEnumMap = {Side.cho: 'cho', Side.han: 'han'};

GameSetup _$GameSetupFromJson(Map<String, dynamic> json) => GameSetup(
  turn: $enumDecode(_$SideEnumMap, json['turn']),
  startsAt: (json['startsAt'] as num).toInt(),
  deadlineAt: (json['deadlineAt'] as num).toInt(),
  han: $enumDecodeNullable(_$FormationEnumMap, json['han']),
  cho: $enumDecodeNullable(_$FormationEnumMap, json['cho']),
);

const _$FormationEnumMap = {
  Formation.horseElephantHorseElephant: 'horseElephantHorseElephant',
  Formation.elephantHorseElephantHorse: 'elephantHorseElephantHorse',
  Formation.horseElephantElephantHorse: 'horseElephantElephantHorse',
  Formation.elephantHorseHorseElephant: 'elephantHorseHorseElephant',
};

SideClocks _$SideClocksFromJson(Map<String, dynamic> json) => SideClocks(
  cho: SideClock.fromJson(json['cho'] as Map<String, dynamic>),
  han: SideClock.fromJson(json['han'] as Map<String, dynamic>),
);

SideClock _$SideClockFromJson(Map<String, dynamic> json) => SideClock(
  baseMs: (json['baseMs'] as num).toInt(),
  periods: (json['periods'] as num).toInt(),
  extensionsUsed: (json['extensionsUsed'] as num).toInt(),
);

SideDisconnects _$SideDisconnectsFromJson(Map<String, dynamic> json) => SideDisconnects(
  cho: SideDisconnect.fromJson(json['cho'] as Map<String, dynamic>),
  han: SideDisconnect.fromJson(json['han'] as Map<String, dynamic>),
);

SideDisconnect _$SideDisconnectFromJson(Map<String, dynamic> json) =>
    SideDisconnect(usedMs: (json['usedMs'] as num).toInt(), since: (json['since'] as num?)?.toInt());

ExtensionNotice _$ExtensionNoticeFromJson(Map<String, dynamic> json) =>
    ExtensionNotice(side: $enumDecode(_$SideEnumMap, json['side']), at: (json['at'] as num).toInt());

GameResultRecord _$GameResultRecordFromJson(Map<String, dynamic> json) => GameResultRecord(
  winner: $enumDecode(_$SideEnumMap, json['winner']),
  reason: $enumDecodeNullable(_$GameEndReasonEnumMap, json['reason'], unknownValue: JsonKey.nullForUndefinedEnumValue),
  choScore: (json['choScore'] as num).toDouble(),
  hanScore: (json['hanScore'] as num).toDouble(),
);

const _$GameEndReasonEnumMap = {
  GameEndReason.checkmate: 'checkmate',
  GameEndReason.resignation: 'resignation',
  GameEndReason.timeout: 'timeout',
  GameEndReason.disconnect: 'disconnect',
  GameEndReason.consecutivePasses: 'consecutivePasses',
  GameEndReason.moveLimit: 'moveLimit',
  GameEndReason.noLegalMoves: 'noLegalMoves',
};

GameMoveRecord _$GameMoveRecordFromJson(Map<String, dynamic> json) =>
    GameMoveRecord(m: json['m'] as String, spentMs: (json['spentMs'] as num).toInt());

GameRematch _$GameRematchFromJson(Map<String, dynamic> json) => GameRematch(
  cho: json['cho'] as bool?,
  han: json['han'] as bool?,
  cancelled: json['cancelled'] as bool?,
  gameId: json['gameId'] as String?,
  blocked: json['blocked'] as bool?,
);
