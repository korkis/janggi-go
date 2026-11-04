import 'dart:math';

import 'package:janggi_core/janggi_core.dart';

import '../config.dart';
import '../http/callable.dart';
import '../models/active_game.dart';
import '../models/connection.dart';
import '../models/game_enums.dart';

// 한 대국의 진행 판정이다(`docs/server.md`의 대국 진행). DB에 닿지 않는 순수 함수로 두고 `GameService`가 부른다.
// 시각은 모두 Unix epoch 밀리초(UTC)다. 수의 합법성과 승패는 `janggi_core`만 판정한다.

/// 상차림 시간 안에 아무것도 고르지 않았을 때의 상차림(`docs/game/time.md`).
const defaultFormation = Formation.horseElephantHorseElephant;

/// 새 대국. 상차림은 만든 시각 [now]에 한부터 시작한다(`docs/server.md`의 대국 만들기와 상차림).
///
/// 방 대국이면 [roomId], 접장기면 한에서 뗄 기물 [handicap]을 준다. 다시 두기로 만든 대국이면 [rematchOf]와 [rematchCount]를 준다. [rematchBlocked]면 이 대국이 끝난 뒤 다시 두기를 받지
/// 않으므로 처음부터 `rematch.blocked`를 쓴다(빠른 대국의 `quickRematchLimit`).
ActiveGame createActiveGame({
  required GameMode mode,
  required bool rated,
  required bool listed,
  required GamePlayers players,
  required TimeControl timeControl,
  required int disconnectLimitMs,
  required int now,
  String? roomId,
  List<HandicapPiece>? handicap,
  String? rematchOf,
  int rematchCount = 0,
  bool rematchBlocked = false,
}) {
  final startsAt = now;
  final clock = SideClock(baseMs: timeControl.baseMs, periods: timeControl.periods, extensionsUsed: 0);
  const disconnect = SideDisconnect(usedMs: 0, since: null);
  return ActiveGame(
    meta: GameMeta(
      mode: mode,
      rated: rated,
      roomId: roomId,
      listed: listed,
      players: players,
      handicap: handicap,
      timeControl: timeControl,
      disconnectLimitMs: disconnectLimitMs,
      rematchOf: rematchOf,
      rematchCount: rematchCount,
      createdAt: now,
    ),
    state: GameState(
      version: 1,
      phase: GamePhase.setup,
      setup: GameSetup(
        turn: Side.han,
        startsAt: startsAt,
        deadlineAt: startsAt + timeControl.setupMs,
        han: null,
        cho: null,
      ),
      initialFen: null,
      turn: null,
      turnStartedAt: null,
      clock: SideClocks(cho: clock, han: clock),
      disconnect: const SideDisconnects(cho: disconnect, han: disconnect),
      extensionNotice: null,
      result: null,
      endedAt: null,
    ),
    moves: const [],
    rematch: rematchBlocked
        ? const GameRematch(cho: null, han: null, cancelled: null, gameId: null, blocked: true)
        : null,
  );
}

/// [now]까지 지나간 사건(상차림 마감, 시간패, 접속 끊김 마감)을 시각 순서대로 적용한다(`docs/server.md`의 판정 다시 보기).
///
/// 먼저 [connections](진영마다 대국자의 `connections` 연결들)로 접속 끊김 기록을 [now]에 맞춘다. 상차림 마감이 지나면
/// [drafts]에 골라 둔 것이나 [defaultFormation]으로 확정하고, 다음 사건은 지금이 아니라 그 마감 시각부터 센다.
/// 대국이 끝나는 사건을 만나면 멈춘다. 바뀐 것이 없으면 [game]을 그대로 돌려준다.
ActiveGame applyDueEvents(
  ActiveGame game,
  int now, {
  required Map<Side, Formation> drafts,
  required Map<Side, List<Connection>> connections,
}) {
  if (game.state.phase == GamePhase.finished) {
    return game;
  }
  final lossAts = <Side, int>{};
  var disconnect = game.state.disconnect;
  for (final side in Side.values) {
    final update = updateDisconnect(
      disconnect.get(side),
      connections[side] ?? const [],
      now: now,
      createdAt: game.meta.createdAt,
      limitMs: game.meta.disconnectLimitMs,
    );
    if (!_isSameDisconnect(update.disconnect, disconnect.get(side))) {
      disconnect = disconnect.copyWithSide(side, update.disconnect);
    }
    final lossAt = update.lossAt;
    if (lossAt != null) {
      lossAts[side] = lossAt;
    }
  }
  var current = identical(disconnect, game.state.disconnect)
      ? game
      : game.copyWith(state: game.state.copyWith(disconnect: disconnect));

  while (current.state.phase != GamePhase.finished) {
    final state = current.state;
    // 접속 끊김 마감 중 가장 이른 것. 같은 시각이면 시계가 먼저다.
    Side? disconnectedSide;
    for (final side in Side.values) {
      final lossAt = lossAts[side];
      if (lossAt != null && lossAt <= now && (disconnectedSide == null || lossAt < lossAts[disconnectedSide]!)) {
        disconnectedSide = side;
      }
    }
    final clockEventAt = state.phase == GamePhase.setup ? state.setup.deadlineAt : getTimeoutAt(current);
    if (clockEventAt <= now && (disconnectedSide == null || clockEventAt <= lossAts[disconnectedSide]!)) {
      if (state.phase == GamePhase.setup) {
        final setup = state.setup;
        current = _confirmFormation(current, setup.turn, drafts[setup.turn] ?? defaultFormation, setup.deadlineAt);
      } else {
        current = _finish(current, replayGame(current).timeout(state.turn!).result!, clockEventAt);
      }
      continue;
    }
    if (disconnectedSide == null) {
      break;
    }
    final played = state.phase == GamePhase.setup ? Game.start(getInitialPosition(current)) : replayGame(current);
    current = _finish(current, played.disconnect(disconnectedSide).result!, lossAts[disconnectedSide]!);
  }
  return current;
}

/// 다음에 판정을 다시 봐야 하는 시각. 상차림 마감, 시간패 시각, 지금 끊겨 있는 쪽의 접속 끊김 마감 중 가장 이른 것이다.
/// 끝난 대국이면 null.
int? getNextEventAt(ActiveGame game) {
  final state = game.state;
  final int clockEventAt;
  switch (state.phase) {
    case GamePhase.finished:
      return null;
    case GamePhase.setup:
      clockEventAt = state.setup.deadlineAt;
    case GamePhase.playing:
      clockEventAt = getTimeoutAt(game);
  }
  var eventAt = clockEventAt;
  for (final side in Side.values) {
    final lossAt = getDisconnectLossAt(state.disconnect.get(side), game.meta.disconnectLimitMs);
    if (lossAt != null && lossAt < eventAt) {
      eventAt = lossAt;
    }
  }
  return eventAt;
}

// ---- 접속 끊김 ----

/// 연결이 [now]에 살아 있는지. 연결되어 있고, 앱이 화면에 떠 있고, [presenceStaleSeconds] 안에 살아 있음을 알렸다.
/// 숨겨진 웹 탭(`tabHidden`)은 브라우저가 타이머를 늦추거나 멈춰 `lastSeenAt`을 믿을 수 없으므로 오래됐는지 보지 않고
/// `online`만 본다. 탭을 닫거나 네트워크가 끊기면 `onDisconnect`가 `online: false`와 그 시각의 `lastSeenAt`을 쓴다.
bool isConnectionActive(Connection connection, int now) {
  if (!connection.online || !connection.foreground) {
    return false;
  }
  if (connection.tabHidden == true) {
    return true;
  }
  return now - connection.lastSeenAt <= const Duration(seconds: presenceStaleSeconds).inMilliseconds;
}

/// [updateDisconnect]의 결과.
class DisconnectUpdate {
  final SideDisconnect disconnect;

  /// 끊긴 시간 합계가 한도에 닿는(닿은) 시각. 지금 연결되어 있고 한도에 닿지 않았으면 null. 판정 시각보다 뒤일 수 있다.
  final int? lossAt;

  const DisconnectUpdate({required this.disconnect, required this.lossAt});
}

/// 한 진영의 접속 끊김 기록 [current]를 판정 시각 [now]에 읽은 그 대국자의 연결들 [connections]로 바꾼다
/// (`docs/server.md`의 접속 끊김).
///
/// - 끊긴 시각은 가장 최근 `lastSeenAt`이다. 대국을 만든 시각 [createdAt]보다 앞이면 만든 시각으로 한다.
/// - 끊긴 뒤 화면에 돌아온 연결(`activeSince`가 끊긴 시각보다 뒤)이 있으면 그 가장 이른 `activeSince`까지를 끊긴 시간으로
///   더한다. 돌아왔다가 다시 끊겼으면 그 연결의 `lastSeenAt`부터 다시 센다.
/// - 연결되어 있는데 끊긴 뒤 돌아온 연결이 없으면(네트워크가 잠깐 멈췄다 이어진 경우) 끊긴 시간을 더하지 않는다.
///   앱은 서버가 자기를 끊긴 것으로 기록한 것을 보면 `activeSince`를 새로 쓰고 `checkGame`을 부른다.
/// - 돌아오기 전에 합계가 [limitMs]에 닿았으면 기록을 바꾸지 않고 그 시각을 [DisconnectUpdate.lossAt]으로 돌려준다.
DisconnectUpdate updateDisconnect(
  SideDisconnect current,
  List<Connection> connections, {
  required int now,
  required int createdAt,
  required int limitMs,
}) {
  final connected = connections.any((connection) => isConnectionActive(connection, now));
  int? lastSeenAt;
  for (final connection in connections) {
    if (lastSeenAt == null || connection.lastSeenAt > lastSeenAt) {
      lastSeenAt = connection.lastSeenAt;
    }
  }
  var usedMs = current.usedMs;
  var since = current.since;
  if (since == null) {
    if (connected) {
      return DisconnectUpdate(disconnect: current, lossAt: null);
    }
    since = min(max(lastSeenAt ?? createdAt, createdAt), now);
    return DisconnectUpdate(
      disconnect: SideDisconnect(usedMs: usedMs, since: since),
      lossAt: since + limitMs - usedMs,
    );
  }

  int? returnedAt;
  for (final connection in connections) {
    if (connection.activeSince > since && (returnedAt == null || connection.activeSince < returnedAt)) {
      returnedAt = connection.activeSince;
    }
  }
  if (connected || returnedAt != null) {
    final backAt = min(returnedAt ?? since, now);
    if (usedMs + backAt - since >= limitMs) {
      return DisconnectUpdate(disconnect: current, lossAt: since + limitMs - usedMs);
    }
    usedMs += backAt - since;
    if (connected) {
      return DisconnectUpdate(disconnect: SideDisconnect(usedMs: usedMs, since: null), lossAt: null);
    }
    since = min(max(lastSeenAt!, backAt), now);
  }
  return DisconnectUpdate(
    disconnect: SideDisconnect(usedMs: usedMs, since: since),
    lossAt: since + limitMs - usedMs,
  );
}

/// 지금 끊겨 있는 쪽이 접속 끊김으로 지는 시각. 끊겨 있지 않으면 null.
int? getDisconnectLossAt(SideDisconnect disconnect, int limitMs) {
  final since = disconnect.since;
  return since == null ? null : since + limitMs - disconnect.usedMs;
}

bool _isSameDisconnect(SideDisconnect a, SideDisconnect b) => a.usedMs == b.usedMs && a.since == b.since;

/// 지금 차례인 쪽의 시간패 시각. "초읽기를 모두 쓴 뒤 한 번 더 초읽기 시간 안에 두지 못하면 시간패"다(`docs/server.md`의 시계).
int getTimeoutAt(ActiveGame game) {
  final state = game.state;
  final turn = state.turn;
  final turnStartedAt = state.turnStartedAt;
  if (state.phase != GamePhase.playing || turn == null || turnStartedAt == null) {
    throw StateError('대국 중이 아니면 시간패 시각이 없습니다');
  }
  final clock = state.clock.get(turn);
  return turnStartedAt + clock.baseMs + (clock.periods + 1) * game.meta.timeControl.periodMs;
}

/// 한 차례에 [spentMs]를 쓴 뒤의 시계. 기본 시간을 넘긴 만큼 초읽기를 [periodMs] 단위로 줄인다.
/// 초읽기 중에 [periodMs] 안에 두면 줄지 않는다(`docs/game/time.md`).
SideClock spendTime(SideClock clock, int spentMs, int periodMs) {
  if (spentMs <= clock.baseMs) {
    return SideClock(baseMs: clock.baseMs - spentMs, periods: clock.periods, extensionsUsed: clock.extensionsUsed);
  }
  final overMs = spentMs - clock.baseMs;
  return SideClock(baseMs: 0, periods: clock.periods - overMs ~/ periodMs, extensionsUsed: clock.extensionsUsed);
}

/// [uid]가 둔 진영. 대국자가 아니면 `notPlayer`로 거절한다.
Side requirePlayerSide(ActiveGame game, String uid) {
  final players = game.meta.players;
  if (players.cho.uid == uid) {
    return Side.cho;
  }
  if (players.han.uid == uid) {
    return Side.han;
  }
  throw const CallableException.failedPrecondition(GameErrorCode.notPlayer, '이 대국의 대국자가 아닙니다');
}

/// [side]가 지금 상차림을 골라 둘 수 있는지 확인한다. 아니면 [CallableException]을 던진다.
void checkCanPickFormation(ActiveGame game, Side side) {
  final state = game.state;
  if (state.phase == GamePhase.finished) {
    throw const CallableException.failedPrecondition(GameErrorCode.gameOver, '이미 끝난 대국입니다');
  }
  if (state.phase != GamePhase.setup || state.setup.turn != side || state.setup.get(side) != null) {
    throw const CallableException.failedPrecondition(GameErrorCode.notYourTurn, '상차림을 고를 차례가 아닙니다');
  }
}

/// [side]가 [formation]으로 상차림을 확정한다. 한이 확정하면 초의 상차림 시간이 [now]부터 시작한다.
ActiveGame confirmFormation(ActiveGame game, Side side, Formation formation, int now) {
  checkCanPickFormation(game, side);
  return _confirmFormation(game, side, formation, now);
}

/// [side]가 [moveIndex]번째 수(0부터)로 [move]를 둔다(`docs/server.md`의 수).
///
/// 같은 수를 다시 보내면(응답을 못 받고 다시 보낸 경우) 바꾸지 않고 [game]을 그대로 돌려준다.
/// 시간패와 접속 끊김은 [applyDueEvents]가 먼저 판정하므로 여기서는 [now]가 시간패 시각 전이다.
ActiveGame playMove(ActiveGame game, Side side, int moveIndex, Move move, int now) {
  final state = game.state;
  if (moveIndex < game.moves.length) {
    if (getMoveSide(moveIndex) == side && game.moves[moveIndex].m == move.toString()) {
      return game;
    }
    throw const CallableException.failedPrecondition(GameErrorCode.moveConflict, '수 번호가 서버와 다릅니다');
  }
  if (state.phase == GamePhase.finished) {
    throw const CallableException.failedPrecondition(GameErrorCode.gameOver, '이미 끝난 대국입니다');
  }
  if (state.phase != GamePhase.playing || state.turn != side) {
    throw const CallableException.failedPrecondition(GameErrorCode.notYourTurn, '내 차례가 아닙니다');
  }
  if (moveIndex != game.moves.length) {
    throw const CallableException.failedPrecondition(GameErrorCode.moveConflict, '수 번호가 서버와 다릅니다');
  }
  final played = replayGame(game);
  if (!played.isLegal(move)) {
    throw const CallableException.failedPrecondition(GameErrorCode.illegalMove, '둘 수 없는 수입니다');
  }
  final spentMs = now - state.turnStartedAt!;
  final timeControl = game.meta.timeControl;
  final clock = state.clock.copyWithSide(side, spendTime(state.clock.get(side), spentMs, timeControl.periodMs));
  final next = played.play(move);
  final moved = game.copyWith(
    state: state.copyWith(turn: side.opponent, turnStartedAt: now, clock: clock),
    moves: [
      ...game.moves,
      GameMoveRecord(m: move.toString(), spentMs: spentMs),
    ],
  );
  final result = next.result;
  if (result == null) {
    return moved;
  }
  return _finish(moved, result, now);
}

/// [side]가 기권한다. 상차림 중에도 할 수 있고 패로 기록한다(`docs/server.md`의 기권).
ActiveGame resign(ActiveGame game, Side side, int now) {
  final GameResult result;
  switch (game.state.phase) {
    case GamePhase.finished:
      throw const CallableException.failedPrecondition(GameErrorCode.gameOver, '이미 끝난 대국입니다');
    case GamePhase.setup:
      result = Game.start(getInitialPosition(game)).resign(side).result!;
    case GamePhase.playing:
      result = replayGame(game).resign(side).result!;
  }
  return _finish(game, result, now);
}

/// [moveIndex]번째 수를 두는 진영. 초부터 번갈아 두고 한수쉼도 한 수로 센다.
Side getMoveSide(int moveIndex) => moveIndex.isEven ? Side.cho : Side.han;

/// 처음 국면. 상차림이 끝났으면 `initialFen`이고, 상차림 중이면 확정한 것과 [defaultFormation]으로 만든다.
/// 상차림 중 기권한 대국의 점수와 기보에 쓴다.
Position getInitialPosition(ActiveGame game) {
  final initialFen = game.state.initialFen;
  if (initialFen != null) {
    return Position.fromFen(initialFen);
  }
  final setup = game.state.setup;
  return createInitialPosition(
    cho: setup.cho ?? defaultFormation,
    han: setup.han ?? defaultFormation,
    hanRemoved: {...?game.meta.handicap},
  );
}

/// 처음 국면에서 지금까지 둔 수를 다시 둔 대국. 수 판정은 여기서 만든 [Game]으로만 한다.
Game replayGame(ActiveGame game) {
  return Game.replay(getInitialPosition(game), game.moves.map((record) => Move.parse(record.m)));
}

ActiveGame _confirmFormation(ActiveGame game, Side side, Formation formation, int at) {
  final state = game.state;
  final setup = state.setup;
  if (side == Side.han) {
    return game.copyWith(
      state: state.copyWith(
        setup: GameSetup(
          turn: Side.cho,
          startsAt: setup.startsAt,
          deadlineAt: at + game.meta.timeControl.setupMs,
          han: formation,
          cho: null,
        ),
      ),
    );
  }
  final han = setup.han!;
  final initialPosition = createInitialPosition(cho: formation, han: han, hanRemoved: {...?game.meta.handicap});
  return game.copyWith(
    state: state.copyWith(
      phase: GamePhase.playing,
      setup: GameSetup(
        turn: Side.cho,
        startsAt: setup.startsAt,
        deadlineAt: setup.deadlineAt,
        han: han,
        cho: formation,
      ),
      initialFen: initialPosition.fen,
      turn: Side.cho,
      turnStartedAt: at,
    ),
  );
}

ActiveGame _finish(ActiveGame game, GameResult result, int endedAt) {
  return game.copyWith(
    state: game.state.copyWith(
      phase: GamePhase.finished,
      result: GameResultRecord(
        winner: result.winner,
        reason: result.reason,
        choScore: result.choScore,
        hanScore: result.hanScore,
      ),
      endedAt: endedAt,
    ),
  );
}

// ---- 다시 두기 ----

/// 연결이 지금 앱 화면에 떠 있는지. 대국이 끝난 뒤에는 `lastSeenAt`을 갱신하지 않으므로 [isConnectionActive]와 달리
/// 오래됐는지는 보지 않는다. 빠른 대국 매칭과 다시 두기에서 상대가 아직 앱에 있는지 볼 때 쓴다.
bool isConnectionPresent(Connection connection) => connection.online && connection.foreground;

/// 다시 두기 횟수에 닿았는지. 빠른 대국만 [quickRematchLimit]으로 제한한다(`docs/game/matching.md`의 다시 두기).
bool isRematchLimitReached(ActiveGame game, int quickRematchLimit) {
  return game.meta.mode == GameMode.quick && game.meta.rematchCount >= quickRematchLimit;
}

/// [side]가 다시 두기를 누른 대국. 두 쪽이 모두 눌렀으면 `rematch.gameId`에 [newGameId]를 써서 새 대국을 만들 사람을
/// 한 요청으로 정한다. 이미 새 대국이 정해졌으면 그대로 돌려준다.
///
/// 상대가 앱에 없으면([opponentPresent]가 false) 결과 화면에서 앱을 끈 것이므로 취소한다(`docs/server.md`의 다시 두기).
/// 상대가 먼저 눌렀어도 같다. 끝나지 않은 대국, 취소됐거나 막힌 다시 두기는 `rematchUnavailable`로 거절한다.
ActiveGame pressRematch(
  ActiveGame game,
  Side side, {
  required int quickRematchLimit,
  required bool opponentPresent,
  required String newGameId,
}) {
  if (game.state.phase != GamePhase.finished) {
    throw const CallableException.failedPrecondition(GameErrorCode.rematchUnavailable, '아직 끝나지 않은 대국입니다');
  }
  final rematch = game.rematch ?? const GameRematch(cho: null, han: null, cancelled: null, gameId: null, blocked: null);
  if (rematch.gameId != null) {
    return game;
  }
  if (rematch.cancelled == true || rematch.blocked == true || isRematchLimitReached(game, quickRematchLimit)) {
    throw const CallableException.failedPrecondition(GameErrorCode.rematchUnavailable, '다시 두기를 할 수 없습니다');
  }
  if (!opponentPresent) {
    return game.copyWith(rematch: rematch.copyWith(cancelled: true));
  }
  final pressed = rematch.copyWithSide(side, true);
  final bothPressed = pressed.get(side.opponent) == true;
  return game.copyWith(rematch: bothPressed ? pressed.copyWith(gameId: newGameId) : pressed);
}

/// 정해 둔 다시 두기 대국을 만들지 못한 대국. 새 대국 ID를 지우고 취소한다. 앱은 취소를 보고 다시 두기를 끝낸다.
ActiveGame failRematch(ActiveGame game) {
  final rematch = game.rematch;
  if (rematch == null || rematch.gameId == null) {
    return game;
  }
  return game.copyWith(
    rematch: GameRematch(cho: rematch.cho, han: rematch.han, cancelled: true, gameId: null, blocked: rematch.blocked),
  );
}

/// 결과 화면을 나간 대국. 새 대국이 아직 정해지지 않았으면 다시 두기를 취소한다. 바꿀 것이 없으면 [game]을 그대로 돌려준다.
ActiveGame cancelRematch(ActiveGame game) {
  final rematch = game.rematch ?? const GameRematch(cho: null, han: null, cancelled: null, gameId: null, blocked: null);
  if (game.state.phase != GamePhase.finished || rematch.gameId != null || rematch.cancelled == true) {
    return game;
  }
  return game.copyWith(rematch: rematch.copyWith(cancelled: true));
}

/// 다시 두기 대국의 대국자. 초와 한을 바꾼다. 접장기면 떼는 쪽이 계속 한이므로 그대로 둔다(`docs/game/handicap.md`).
/// 닉네임과 급수는 [refreshed]의 지금 값으로 바꾼다.
GamePlayers getRematchPlayers(ActiveGame previous, Map<String, GamePlayer> refreshed) {
  final players = previous.meta.players;
  final cho = refreshed[players.cho.uid] ?? players.cho;
  final han = refreshed[players.han.uid] ?? players.han;
  if (previous.meta.handicap != null) {
    return GamePlayers(cho: cho, han: han);
  }
  return GamePlayers(cho: han, han: cho);
}
