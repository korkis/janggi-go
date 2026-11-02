import 'package:janggi_core/janggi_core.dart';
import 'package:json_annotation/json_annotation.dart';

import 'game_enums.dart';

part 'active_game.g.dart';

// RTDB `games_active/{gameId}`. 진행 중이거나 막 끝난 대국이다(`docs/database.md`).
// 필드는 앱의 같은 이름 모델(`app/lib/models/active_game.dart`)과 일치시킨다.
// 시각은 모두 Unix epoch 밀리초(UTC)다. RTDB는 null과 빈 목록을 저장하지 않으므로 그런 필드는 경로가 없다.

@JsonSerializable(createToJson: true, explicitToJson: true, includeIfNull: false)
class ActiveGame {
  final GameMeta meta;
  final GameState state;

  /// 둔 수. 아직 없으면 RTDB에 경로가 없으므로 빈 목록으로 읽는다.
  @JsonKey(defaultValue: <GameMoveRecord>[])
  final List<GameMoveRecord> moves;

  /// 다시 두기 상태. 7단계(빠른 대국)부터 쓴다.
  final GameRematch? rematch;

  const ActiveGame({required this.meta, required this.state, required this.moves, required this.rematch});

  factory ActiveGame.fromJson(Map<String, dynamic> json) => _$ActiveGameFromJson(json);

  Map<String, dynamic> toJson() => _$ActiveGameToJson(this);

  ActiveGame copyWith({GameState? state, List<GameMoveRecord>? moves}) {
    return ActiveGame(meta: meta, state: state ?? this.state, moves: moves ?? this.moves, rematch: rematch);
  }
}

/// 대국을 만들 때 쓰고 바꾸지 않는 값.
@JsonSerializable(createToJson: true, explicitToJson: true, includeIfNull: false)
class GameMeta {
  final GameMode mode;

  /// 급수에 반영하는 대국.
  final bool rated;
  final String? roomId;

  /// 관전 목록에 보인다. 비공개 방 대국은 false.
  final bool listed;
  final GamePlayers players;

  /// 한에서 뗀 기물. 접장기가 아니면 null.
  final List<HandicapPiece>? handicap;
  final TimeControl timeControl;

  /// 대국을 만들 때의 `configs/app.disconnectLimitSeconds`(밀리초).
  final int disconnectLimitMs;
  final String? rematchOf;

  /// 빠른 대국에서 같은 상대와 연달아 다시 둔 횟수. 첫 대국은 0.
  final int rematchCount;
  final int createdAt;

  const GameMeta({
    required this.mode,
    required this.rated,
    required this.roomId,
    required this.listed,
    required this.players,
    required this.handicap,
    required this.timeControl,
    required this.disconnectLimitMs,
    required this.rematchOf,
    required this.rematchCount,
    required this.createdAt,
  });

  factory GameMeta.fromJson(Map<String, dynamic> json) => _$GameMetaFromJson(json);

  Map<String, dynamic> toJson() => _$GameMetaToJson(this);
}

@JsonSerializable(createToJson: true, explicitToJson: true, includeIfNull: false)
class GamePlayers {
  final GamePlayer cho;
  final GamePlayer han;

  const GamePlayers({required this.cho, required this.han});

  factory GamePlayers.fromJson(Map<String, dynamic> json) => _$GamePlayersFromJson(json);

  Map<String, dynamic> toJson() => _$GamePlayersToJson(this);

  GamePlayer get(Side side) => side == Side.cho ? cho : han;
}

/// 대국자. 닉네임과 급수는 대국을 만들 때의 값이다.
@JsonSerializable(createToJson: true, includeIfNull: false)
class GamePlayer {
  final String uid;
  final String nickname;
  final int rankLevel;

  const GamePlayer({required this.uid, required this.nickname, required this.rankLevel});

  factory GamePlayer.fromJson(Map<String, dynamic> json) => _$GamePlayerFromJson(json);

  Map<String, dynamic> toJson() => _$GamePlayerToJson(this);
}

/// 시간 규칙(`docs/game/time.md`). 대국을 만들 때 대국 서버 설정을 복사한다.
@JsonSerializable(createToJson: true, includeIfNull: false)
class TimeControl {
  /// 기본 시간.
  final int baseMs;

  /// 초읽기 한 번의 시간.
  final int periodMs;

  /// 초읽기 횟수.
  final int periods;

  /// 한 진영의 상차림 시간.
  final int setupMs;

  /// 시간 연장 1회에 늘어나는 초읽기 횟수.
  final int extensionPeriods;

  /// 시간 연장을 쓸 수 있는 최대 횟수.
  final int extensionLimit;

  const TimeControl({
    required this.baseMs,
    required this.periodMs,
    required this.periods,
    required this.setupMs,
    required this.extensionPeriods,
    required this.extensionLimit,
  });

  factory TimeControl.fromJson(Map<String, dynamic> json) => _$TimeControlFromJson(json);

  Map<String, dynamic> toJson() => _$TimeControlToJson(this);
}

/// 대국이 진행되며 바뀌는 값. 대국 서버가 쓸 때마다 [version]을 1 늘린다.
@JsonSerializable(createToJson: true, explicitToJson: true, includeIfNull: false)
class GameState {
  final int version;
  final GamePhase phase;
  final GameSetup setup;

  /// 상차림과 접장기를 반영한 처음 국면. 양쪽 상차림이 끝나면 쓴다.
  final String? initialFen;

  /// 둘 차례. 상차림 중에는 null.
  final Side? turn;

  /// 지금 차례가 시작된 서버 시각.
  final int? turnStartedAt;

  /// 각 진영의 남은 시간. 차례가 넘어갈 때만 바꾼다.
  final SideClocks clock;
  final SideDisconnects disconnect;

  /// 마지막 시간 연장. 상대 화면 표시용.
  final ExtensionNotice? extensionNotice;
  final GameResultRecord? result;
  final int? endedAt;

  const GameState({
    required this.version,
    required this.phase,
    required this.setup,
    required this.initialFen,
    required this.turn,
    required this.turnStartedAt,
    required this.clock,
    required this.disconnect,
    required this.extensionNotice,
    required this.result,
    required this.endedAt,
  });

  factory GameState.fromJson(Map<String, dynamic> json) => _$GameStateFromJson(json);

  Map<String, dynamic> toJson() => _$GameStateToJson(this);

  /// 바꿀 값만 넘긴다. 이 값들은 한 번 정해지면 null로 돌아가지 않는다.
  GameState copyWith({
    int? version,
    GamePhase? phase,
    GameSetup? setup,
    String? initialFen,
    Side? turn,
    int? turnStartedAt,
    SideClocks? clock,
    GameResultRecord? result,
    int? endedAt,
  }) {
    return GameState(
      version: version ?? this.version,
      phase: phase ?? this.phase,
      setup: setup ?? this.setup,
      initialFen: initialFen ?? this.initialFen,
      turn: turn ?? this.turn,
      turnStartedAt: turnStartedAt ?? this.turnStartedAt,
      clock: clock ?? this.clock,
      disconnect: disconnect,
      extensionNotice: extensionNotice,
      result: result ?? this.result,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}

/// 상차림. 한이 먼저 고르고 초는 한이 확정한 뒤 고른다(`docs/game/rules.md`).
@JsonSerializable(createToJson: true, includeIfNull: false)
class GameSetup {
  /// 지금 고르는 진영. 양쪽이 끝난 뒤에는 마지막으로 고른 초로 남는다.
  final Side turn;

  /// 상대 찾음 화면이 끝나고 한의 상차림 시간이 시작되는 시각.
  final int startsAt;

  /// 지금 고르는 진영의 마감 시각. 지나면 골라 둔 것이나 기본 상차림으로 확정한다.
  final int deadlineAt;

  /// 확정한 상차림. 골라 두기만 한 것은 상대에게 보이지 않게 `player_states.setupDraft`에 둔다.
  final Formation? han;
  final Formation? cho;

  const GameSetup({
    required this.turn,
    required this.startsAt,
    required this.deadlineAt,
    required this.han,
    required this.cho,
  });

  factory GameSetup.fromJson(Map<String, dynamic> json) => _$GameSetupFromJson(json);

  Map<String, dynamic> toJson() => _$GameSetupToJson(this);

  Formation? get(Side side) => side == Side.cho ? cho : han;
}

@JsonSerializable(createToJson: true, explicitToJson: true, includeIfNull: false)
class SideClocks {
  final SideClock cho;
  final SideClock han;

  const SideClocks({required this.cho, required this.han});

  factory SideClocks.fromJson(Map<String, dynamic> json) => _$SideClocksFromJson(json);

  Map<String, dynamic> toJson() => _$SideClocksToJson(this);

  SideClock get(Side side) => side == Side.cho ? cho : han;

  SideClocks copyWithSide(Side side, SideClock clock) {
    return side == Side.cho ? SideClocks(cho: clock, han: han) : SideClocks(cho: cho, han: clock);
  }
}

/// 한 진영의 시계. 차례가 시작될 때의 값이다.
@JsonSerializable(createToJson: true, includeIfNull: false)
class SideClock {
  /// 남은 기본 시간.
  final int baseMs;

  /// 남은 초읽기 횟수.
  final int periods;
  final int extensionsUsed;

  const SideClock({required this.baseMs, required this.periods, required this.extensionsUsed});

  factory SideClock.fromJson(Map<String, dynamic> json) => _$SideClockFromJson(json);

  Map<String, dynamic> toJson() => _$SideClockToJson(this);
}

@JsonSerializable(createToJson: true, explicitToJson: true, includeIfNull: false)
class SideDisconnects {
  final SideDisconnect cho;
  final SideDisconnect han;

  const SideDisconnects({required this.cho, required this.han});

  factory SideDisconnects.fromJson(Map<String, dynamic> json) => _$SideDisconnectsFromJson(json);

  Map<String, dynamic> toJson() => _$SideDisconnectsToJson(this);
}

/// 한 진영의 접속 끊김 기록. 6단계(접속 끊김)부터 쓴다.
@JsonSerializable(createToJson: true, includeIfNull: false)
class SideDisconnect {
  /// 지금까지 끊긴 시간 합계.
  final int usedMs;

  /// 지금 끊겨 있으면 끊긴 시각.
  final int? since;

  const SideDisconnect({required this.usedMs, required this.since});

  factory SideDisconnect.fromJson(Map<String, dynamic> json) => _$SideDisconnectFromJson(json);

  Map<String, dynamic> toJson() => _$SideDisconnectToJson(this);
}

@JsonSerializable(createToJson: true, includeIfNull: false)
class ExtensionNotice {
  final Side side;
  final int at;

  const ExtensionNotice({required this.side, required this.at});

  factory ExtensionNotice.fromJson(Map<String, dynamic> json) => _$ExtensionNoticeFromJson(json);

  Map<String, dynamic> toJson() => _$ExtensionNoticeToJson(this);
}

/// 대국 결과. 점수에는 한의 덤이 들어 있다. `games_archived.result`도 같은 모양이다.
@JsonSerializable(createToJson: true, includeIfNull: false)
class GameResultRecord {
  final Side winner;
  final GameEndReason reason;
  final double choScore;
  final double hanScore;

  const GameResultRecord({required this.winner, required this.reason, required this.choScore, required this.hanScore});

  factory GameResultRecord.fromJson(Map<String, dynamic> json) => _$GameResultRecordFromJson(json);

  Map<String, dynamic> toJson() => _$GameResultRecordToJson(this);
}

/// 둔 수 하나. RTDB `moves/{index}`.
@JsonSerializable(createToJson: true, includeIfNull: false)
class GameMoveRecord {
  /// 수 표기(`b1c3`, `pass`).
  final String m;

  /// 이 수에 쓴 시간.
  final int spentMs;

  const GameMoveRecord({required this.m, required this.spentMs});

  factory GameMoveRecord.fromJson(Map<String, dynamic> json) => _$GameMoveRecordFromJson(json);

  Map<String, dynamic> toJson() => _$GameMoveRecordToJson(this);
}

/// 다시 두기. 7단계(빠른 대국)부터 쓴다.
@JsonSerializable(createToJson: true, includeIfNull: false)
class GameRematch {
  final bool? cho;
  final bool? han;
  final bool? cancelled;
  final String? gameId;
  final bool? blocked;

  const GameRematch({
    required this.cho,
    required this.han,
    required this.cancelled,
    required this.gameId,
    required this.blocked,
  });

  factory GameRematch.fromJson(Map<String, dynamic> json) => _$GameRematchFromJson(json);

  Map<String, dynamic> toJson() => _$GameRematchToJson(this);
}
