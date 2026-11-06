// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_game.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActiveGame _$ActiveGameFromJson(Map<String, dynamic> json) => $checkedCreate('ActiveGame', json, ($checkedConvert) {
  final val = ActiveGame(
    meta: $checkedConvert('meta', (v) => GameMeta.fromJson(v as Map<String, dynamic>)),
    state: $checkedConvert('state', (v) => GameState.fromJson(v as Map<String, dynamic>)),
    moves: $checkedConvert(
      'moves',
      (v) => (v as List<dynamic>?)?.map((e) => GameMoveRecord.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    ),
    rematch: $checkedConvert('rematch', (v) => v == null ? null : GameRematch.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

Map<String, dynamic> _$ActiveGameToJson(ActiveGame instance) => <String, dynamic>{
  'meta': instance.meta.toJson(),
  'state': instance.state.toJson(),
  'moves': instance.moves.map((e) => e.toJson()).toList(),
  'rematch': ?instance.rematch?.toJson(),
};

GameMeta _$GameMetaFromJson(Map<String, dynamic> json) => $checkedCreate('GameMeta', json, ($checkedConvert) {
  final val = GameMeta(
    mode: $checkedConvert('mode', (v) => $enumDecode(_$GameModeEnumMap, v)),
    rated: $checkedConvert('rated', (v) => v as bool),
    roomId: $checkedConvert('roomId', (v) => v as String?),
    listed: $checkedConvert('listed', (v) => v as bool),
    players: $checkedConvert('players', (v) => GamePlayers.fromJson(v as Map<String, dynamic>)),
    handicap: $checkedConvert(
      'handicap',
      (v) => (v as List<dynamic>?)?.map((e) => $enumDecode(_$HandicapPieceEnumMap, e)).toList(),
    ),
    timeControl: $checkedConvert('timeControl', (v) => TimeControl.fromJson(v as Map<String, dynamic>)),
    disconnectLimitMs: $checkedConvert('disconnectLimitMs', (v) => (v as num).toInt()),
    rematchOf: $checkedConvert('rematchOf', (v) => v as String?),
    rematchCount: $checkedConvert('rematchCount', (v) => (v as num).toInt()),
    createdAt: $checkedConvert('createdAt', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$GameMetaToJson(GameMeta instance) => <String, dynamic>{
  'mode': _$GameModeEnumMap[instance.mode]!,
  'rated': instance.rated,
  'roomId': ?instance.roomId,
  'listed': instance.listed,
  'players': instance.players.toJson(),
  'handicap': ?instance.handicap?.map((e) => _$HandicapPieceEnumMap[e]!).toList(),
  'timeControl': instance.timeControl.toJson(),
  'disconnectLimitMs': instance.disconnectLimitMs,
  'rematchOf': ?instance.rematchOf,
  'rematchCount': instance.rematchCount,
  'createdAt': instance.createdAt,
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

GamePlayers _$GamePlayersFromJson(Map<String, dynamic> json) => $checkedCreate('GamePlayers', json, ($checkedConvert) {
  final val = GamePlayers(
    cho: $checkedConvert('cho', (v) => GamePlayer.fromJson(v as Map<String, dynamic>)),
    han: $checkedConvert('han', (v) => GamePlayer.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

Map<String, dynamic> _$GamePlayersToJson(GamePlayers instance) => <String, dynamic>{
  'cho': instance.cho.toJson(),
  'han': instance.han.toJson(),
};

GamePlayer _$GamePlayerFromJson(Map<String, dynamic> json) => $checkedCreate('GamePlayer', json, ($checkedConvert) {
  final val = GamePlayer(
    uid: $checkedConvert('uid', (v) => v as String),
    nickname: $checkedConvert('nickname', (v) => v as String),
    rankLevel: $checkedConvert('rankLevel', (v) => (v as num).toInt()),
    pieceMaterial: $checkedConvert('pieceMaterial', (v) => $enumDecodeNullable(_$PieceMaterialEnumMap, v)),
  );
  return val;
});

Map<String, dynamic> _$GamePlayerToJson(GamePlayer instance) => <String, dynamic>{
  'uid': instance.uid,
  'nickname': instance.nickname,
  'rankLevel': instance.rankLevel,
  'pieceMaterial': ?_$PieceMaterialEnumMap[instance.pieceMaterial],
};

const _$PieceMaterialEnumMap = {
  PieceMaterial.plastic: 'plastic',
  PieceMaterial.wood: 'wood',
  PieceMaterial.aluminum: 'aluminum',
};

TimeControl _$TimeControlFromJson(Map<String, dynamic> json) => $checkedCreate('TimeControl', json, ($checkedConvert) {
  final val = TimeControl(
    baseMs: $checkedConvert('baseMs', (v) => (v as num).toInt()),
    periodMs: $checkedConvert('periodMs', (v) => (v as num).toInt()),
    periods: $checkedConvert('periods', (v) => (v as num).toInt()),
    setupMs: $checkedConvert('setupMs', (v) => (v as num).toInt()),
    extensionPeriods: $checkedConvert('extensionPeriods', (v) => (v as num).toInt()),
    extensionLimit: $checkedConvert('extensionLimit', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$TimeControlToJson(TimeControl instance) => <String, dynamic>{
  'baseMs': instance.baseMs,
  'periodMs': instance.periodMs,
  'periods': instance.periods,
  'setupMs': instance.setupMs,
  'extensionPeriods': instance.extensionPeriods,
  'extensionLimit': instance.extensionLimit,
};

GameState _$GameStateFromJson(Map<String, dynamic> json) => $checkedCreate('GameState', json, ($checkedConvert) {
  final val = GameState(
    version: $checkedConvert('version', (v) => (v as num).toInt()),
    phase: $checkedConvert('phase', (v) => $enumDecode(_$GamePhaseEnumMap, v)),
    setup: $checkedConvert('setup', (v) => GameSetup.fromJson(v as Map<String, dynamic>)),
    initialFen: $checkedConvert('initialFen', (v) => v as String?),
    turn: $checkedConvert('turn', (v) => $enumDecodeNullable(_$SideEnumMap, v)),
    turnStartedAt: $checkedConvert('turnStartedAt', (v) => (v as num?)?.toInt()),
    clock: $checkedConvert('clock', (v) => SideClocks.fromJson(v as Map<String, dynamic>)),
    disconnect: $checkedConvert('disconnect', (v) => SideDisconnects.fromJson(v as Map<String, dynamic>)),
    extensionNotice: $checkedConvert(
      'extensionNotice',
      (v) => v == null ? null : ExtensionNotice.fromJson(v as Map<String, dynamic>),
    ),
    result: $checkedConvert('result', (v) => v == null ? null : GameResultRecord.fromJson(v as Map<String, dynamic>)),
    endedAt: $checkedConvert('endedAt', (v) => (v as num?)?.toInt()),
  );
  return val;
});

Map<String, dynamic> _$GameStateToJson(GameState instance) => <String, dynamic>{
  'version': instance.version,
  'phase': _$GamePhaseEnumMap[instance.phase]!,
  'setup': instance.setup.toJson(),
  'initialFen': ?instance.initialFen,
  'turn': ?_$SideEnumMap[instance.turn],
  'turnStartedAt': ?instance.turnStartedAt,
  'clock': instance.clock.toJson(),
  'disconnect': instance.disconnect.toJson(),
  'extensionNotice': ?instance.extensionNotice?.toJson(),
  'result': ?instance.result?.toJson(),
  'endedAt': ?instance.endedAt,
};

const _$GamePhaseEnumMap = {GamePhase.setup: 'setup', GamePhase.playing: 'playing', GamePhase.finished: 'finished'};

const _$SideEnumMap = {Side.cho: 'cho', Side.han: 'han'};

GameSetup _$GameSetupFromJson(Map<String, dynamic> json) => $checkedCreate('GameSetup', json, ($checkedConvert) {
  final val = GameSetup(
    turn: $checkedConvert('turn', (v) => $enumDecode(_$SideEnumMap, v)),
    startsAt: $checkedConvert('startsAt', (v) => (v as num).toInt()),
    deadlineAt: $checkedConvert('deadlineAt', (v) => (v as num).toInt()),
    han: $checkedConvert('han', (v) => $enumDecodeNullable(_$FormationEnumMap, v)),
    cho: $checkedConvert('cho', (v) => $enumDecodeNullable(_$FormationEnumMap, v)),
  );
  return val;
});

Map<String, dynamic> _$GameSetupToJson(GameSetup instance) => <String, dynamic>{
  'turn': _$SideEnumMap[instance.turn]!,
  'startsAt': instance.startsAt,
  'deadlineAt': instance.deadlineAt,
  'han': ?_$FormationEnumMap[instance.han],
  'cho': ?_$FormationEnumMap[instance.cho],
};

const _$FormationEnumMap = {
  Formation.horseElephantHorseElephant: 'horseElephantHorseElephant',
  Formation.elephantHorseElephantHorse: 'elephantHorseElephantHorse',
  Formation.horseElephantElephantHorse: 'horseElephantElephantHorse',
  Formation.elephantHorseHorseElephant: 'elephantHorseHorseElephant',
};

SideClocks _$SideClocksFromJson(Map<String, dynamic> json) => $checkedCreate('SideClocks', json, ($checkedConvert) {
  final val = SideClocks(
    cho: $checkedConvert('cho', (v) => SideClock.fromJson(v as Map<String, dynamic>)),
    han: $checkedConvert('han', (v) => SideClock.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

Map<String, dynamic> _$SideClocksToJson(SideClocks instance) => <String, dynamic>{
  'cho': instance.cho.toJson(),
  'han': instance.han.toJson(),
};

SideClock _$SideClockFromJson(Map<String, dynamic> json) => $checkedCreate('SideClock', json, ($checkedConvert) {
  final val = SideClock(
    baseMs: $checkedConvert('baseMs', (v) => (v as num).toInt()),
    periods: $checkedConvert('periods', (v) => (v as num).toInt()),
    extensionsUsed: $checkedConvert('extensionsUsed', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$SideClockToJson(SideClock instance) => <String, dynamic>{
  'baseMs': instance.baseMs,
  'periods': instance.periods,
  'extensionsUsed': instance.extensionsUsed,
};

SideDisconnects _$SideDisconnectsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SideDisconnects', json, ($checkedConvert) {
      final val = SideDisconnects(
        cho: $checkedConvert('cho', (v) => SideDisconnect.fromJson(v as Map<String, dynamic>)),
        han: $checkedConvert('han', (v) => SideDisconnect.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    });

Map<String, dynamic> _$SideDisconnectsToJson(SideDisconnects instance) => <String, dynamic>{
  'cho': instance.cho.toJson(),
  'han': instance.han.toJson(),
};

SideDisconnect _$SideDisconnectFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SideDisconnect', json, ($checkedConvert) {
      final val = SideDisconnect(
        usedMs: $checkedConvert('usedMs', (v) => (v as num).toInt()),
        since: $checkedConvert('since', (v) => (v as num?)?.toInt()),
      );
      return val;
    });

Map<String, dynamic> _$SideDisconnectToJson(SideDisconnect instance) => <String, dynamic>{
  'usedMs': instance.usedMs,
  'since': ?instance.since,
};

ExtensionNotice _$ExtensionNoticeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExtensionNotice', json, ($checkedConvert) {
      final val = ExtensionNotice(
        side: $checkedConvert('side', (v) => $enumDecode(_$SideEnumMap, v)),
        at: $checkedConvert('at', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$ExtensionNoticeToJson(ExtensionNotice instance) => <String, dynamic>{
  'side': _$SideEnumMap[instance.side]!,
  'at': instance.at,
};

GameResultRecord _$GameResultRecordFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GameResultRecord', json, ($checkedConvert) {
      final val = GameResultRecord(
        winner: $checkedConvert('winner', (v) => $enumDecode(_$SideEnumMap, v)),
        reason: $checkedConvert('reason', (v) => $enumDecode(_$GameEndReasonEnumMap, v)),
        choScore: $checkedConvert('choScore', (v) => (v as num).toDouble()),
        hanScore: $checkedConvert('hanScore', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$GameResultRecordToJson(GameResultRecord instance) => <String, dynamic>{
  'winner': _$SideEnumMap[instance.winner]!,
  'reason': _$GameEndReasonEnumMap[instance.reason]!,
  'choScore': instance.choScore,
  'hanScore': instance.hanScore,
};

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
    $checkedCreate('GameMoveRecord', json, ($checkedConvert) {
      final val = GameMoveRecord(
        m: $checkedConvert('m', (v) => v as String),
        spentMs: $checkedConvert('spentMs', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$GameMoveRecordToJson(GameMoveRecord instance) => <String, dynamic>{
  'm': instance.m,
  'spentMs': instance.spentMs,
};

GameRematch _$GameRematchFromJson(Map<String, dynamic> json) => $checkedCreate('GameRematch', json, ($checkedConvert) {
  final val = GameRematch(
    cho: $checkedConvert('cho', (v) => v as bool?),
    han: $checkedConvert('han', (v) => v as bool?),
    cancelled: $checkedConvert('cancelled', (v) => v as bool?),
    gameId: $checkedConvert('gameId', (v) => v as String?),
    blocked: $checkedConvert('blocked', (v) => v as bool?),
  );
  return val;
});

Map<String, dynamic> _$GameRematchToJson(GameRematch instance) => <String, dynamic>{
  'cho': ?instance.cho,
  'han': ?instance.han,
  'cancelled': ?instance.cancelled,
  'gameId': ?instance.gameId,
  'blocked': ?instance.blocked,
};
