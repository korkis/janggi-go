import 'package:janggi_core/janggi_core.dart';

import '../http/callable.dart';
import '../models/active_game.dart';
import '../models/game_enums.dart';

// 한 대국의 진행 판정이다(`docs/server.md`의 대국 진행). DB에 닿지 않는 순수 함수로 두고 `GameService`가 부른다.
// 시각은 모두 Unix epoch 밀리초(UTC)다. 수의 합법성과 승패는 `janggi_core`만 판정한다.

/// 상차림 시간 안에 아무것도 고르지 않았을 때의 상차림(`docs/game/time.md`).
const defaultFormation = Formation.horseElephantHorseElephant;

/// 새 대국. 상차림은 [now] + [introMs]에 한부터 시작한다.
ActiveGame createActiveGame({
  required GameMode mode,
  required bool rated,
  required bool listed,
  required GamePlayers players,
  required TimeControl timeControl,
  required int disconnectLimitMs,
  required int introMs,
  required int now,
}) {
  final startsAt = now + introMs;
  final clock = SideClock(baseMs: timeControl.baseMs, periods: timeControl.periods, extensionsUsed: 0);
  const disconnect = SideDisconnect(usedMs: 0, since: null);
  return ActiveGame(
    meta: GameMeta(
      mode: mode,
      rated: rated,
      roomId: null,
      listed: listed,
      players: players,
      handicap: null,
      timeControl: timeControl,
      disconnectLimitMs: disconnectLimitMs,
      rematchOf: null,
      rematchCount: 0,
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
    rematch: null,
  );
}

/// [now]까지 지나간 사건(상차림 마감, 시간패)을 시각 순서대로 적용한다(`docs/server.md`의 판정 다시 보기).
///
/// 상차림 마감이 지나면 [drafts]에 골라 둔 것이나 [defaultFormation]으로 확정하고, 다음 사건은 지금이 아니라 그 마감 시각부터
/// 센다. 대국이 끝나는 사건을 만나면 멈춘다. 지난 사건이 없으면 [game]을 그대로 돌려준다.
ActiveGame applyDueEvents(ActiveGame game, int now, {required Map<Side, Formation> drafts}) {
  var current = game;
  while (true) {
    final state = current.state;
    switch (state.phase) {
      case GamePhase.finished:
        return current;
      case GamePhase.setup:
        final setup = state.setup;
        if (now < setup.deadlineAt) {
          return current;
        }
        current = _confirmFormation(current, setup.turn, drafts[setup.turn] ?? defaultFormation, setup.deadlineAt);
      case GamePhase.playing:
        final timeoutAt = getTimeoutAt(current);
        if (now < timeoutAt) {
          return current;
        }
        final result = replayGame(current).timeout(state.turn!).result!;
        current = _finish(current, result, timeoutAt);
    }
  }
}

/// 다음에 판정을 다시 봐야 하는 시각. 상차림 마감 또는 시간패 시각이다. 끝난 대국이면 null.
int? getNextEventAt(ActiveGame game) {
  return switch (game.state.phase) {
    GamePhase.setup => game.state.setup.deadlineAt,
    GamePhase.playing => getTimeoutAt(game),
    GamePhase.finished => null,
  };
}

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
/// 시간패는 [applyDueEvents]가 먼저 판정하므로 여기서는 [now]가 시간패 시각 전이다.
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
