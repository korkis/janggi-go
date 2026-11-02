import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo_game/config.dart';
import 'package:janggigo_game/http/callable.dart';
import 'package:janggigo_game/models/active_game.dart';
import 'package:janggigo_game/models/connection.dart';
import 'package:janggigo_game/models/game_enums.dart';
import 'package:janggigo_game/services/game_rules.dart';
import 'package:test/test.dart';

const _createdAt = 1000000;
const _introMs = matchIntroSeconds * 1000;
const _setupMs = 20000;
const _startsAt = _createdAt + _introMs;

ActiveGame _newGame() {
  return createActiveGame(
    mode: GameMode.challenge,
    rated: false,
    listed: true,
    players: const GamePlayers(
      cho: GamePlayer(uid: 'cho-uid', nickname: '초사람', rankLevel: 1),
      han: GamePlayer(uid: 'han-uid', nickname: '한사람', rankLevel: 2),
    ),
    timeControl: defaultTimeControl,
    disconnectLimitMs: 30000,
    introMs: _introMs,
    now: _createdAt,
  );
}

/// 양쪽이 상차림을 마치고 [startedAt]에 초 차례가 시작된 대국.
ActiveGame _playingGame({int startedAt = _startsAt + 1000}) {
  final hanDone = confirmFormation(_newGame(), Side.han, Formation.elephantHorseElephantHorse, _startsAt + 500);
  return confirmFormation(hanDone, Side.cho, Formation.horseElephantElephantHorse, startedAt);
}

const _limitMs = 30000;

/// [lastSeenAt]까지 살아 있음을 알린 화면에 떠 있는 연결.
Connection _active({required int activeSince, required int lastSeenAt}) =>
    Connection(online: true, foreground: true, activeSince: activeSince, lastSeenAt: lastSeenAt);

/// [lastSeenAt]에 끊긴 연결.
Connection _offline({required int activeSince, required int lastSeenAt}) =>
    Connection(online: false, foreground: true, activeSince: activeSince, lastSeenAt: lastSeenAt);

/// 두 대국자 모두 [now]에 연결되어 있다.
Map<Side, List<Connection>> _bothConnected(int now) => {
  Side.cho: [_active(activeSince: _createdAt, lastSeenAt: now)],
  Side.han: [_active(activeSince: _createdAt, lastSeenAt: now)],
};

Matcher _rejectedWith(GameErrorCode code) =>
    throwsA(isA<CallableException>().having((error) => error.code, 'code', code));

void main() {
  group('상차림', () {
    test('새 대국은 상대 찾음 화면 뒤에 한부터 20초를 받는다', () {
      final game = _newGame();
      expect(game.state.phase, GamePhase.setup);
      expect(game.state.setup.turn, Side.han);
      expect(game.state.setup.startsAt, _startsAt);
      expect(game.state.setup.deadlineAt, _startsAt + _setupMs);
      expect(getNextEventAt(game), _startsAt + _setupMs);
    });

    test('한이 확정하면 초는 그때부터 20초를 받는다', () {
      final game = confirmFormation(_newGame(), Side.han, Formation.elephantHorseElephantHorse, _startsAt + 7000);
      expect(game.state.setup.han, Formation.elephantHorseElephantHorse);
      expect(game.state.setup.turn, Side.cho);
      expect(game.state.setup.deadlineAt, _startsAt + 7000 + _setupMs);
    });

    test('초가 확정하면 처음 국면을 만들고 초 차례를 시작한다', () {
      final game = _playingGame(startedAt: _startsAt + 9000);
      expect(game.state.phase, GamePhase.playing);
      expect(game.state.turn, Side.cho);
      expect(game.state.turnStartedAt, _startsAt + 9000);
      expect(
        game.state.initialFen,
        createInitialPosition(cho: Formation.horseElephantElephantHorse, han: Formation.elephantHorseElephantHorse).fen,
      );
    });

    test('자기 차례가 아니면 고를 수 없다', () {
      expect(
        () => confirmFormation(_newGame(), Side.cho, Formation.horseElephantHorseElephant, _startsAt),
        _rejectedWith(GameErrorCode.notYourTurn),
      );
      expect(() => checkCanPickFormation(_playingGame(), Side.cho), _rejectedWith(GameErrorCode.notYourTurn));
    });

    test('마감이 지나면 골라 둔 것으로, 없으면 기본 상차림으로 확정하고 다음 마감은 앞 마감부터 센다', () {
      final hanDeadline = _startsAt + _setupMs;
      final game = applyDueEvents(
        _newGame(),
        hanDeadline + _setupMs + 5000,
        drafts: {Side.han: Formation.horseElephantElephantHorse},
        connections: _bothConnected(hanDeadline + _setupMs + 5000),
      );
      expect(game.state.setup.han, Formation.horseElephantElephantHorse);
      expect(game.state.setup.cho, defaultFormation);
      expect(game.state.phase, GamePhase.playing);
      // 초의 마감은 한의 마감 + 20초이고, 초의 차례는 지금이 아니라 그 마감부터 시작한다.
      expect(game.state.turnStartedAt, hanDeadline + _setupMs);
    });

    test('마감 전에는 바꾸지 않는다', () {
      final game = _newGame();
      final now = _startsAt + _setupMs - 1;
      expect(identical(applyDueEvents(game, now, drafts: const {}, connections: _bothConnected(now)), game), isTrue);
    });
  });

  group('시계', () {
    test('기본 시간 안에 두면 기본 시간에서 뺀다', () {
      const clock = SideClock(baseMs: 300000, periods: 3, extensionsUsed: 0);
      final next = spendTime(clock, 12000, 30000);
      expect(next.baseMs, 288000);
      expect(next.periods, 3);
    });

    test('기본 시간을 넘기면 넘긴 만큼 초읽기를 줄인다', () {
      const clock = SideClock(baseMs: 10000, periods: 3, extensionsUsed: 0);
      expect(spendTime(clock, 39999, 30000).periods, 3);
      expect(spendTime(clock, 40000, 30000).periods, 2);
      expect(spendTime(clock, 75000, 30000).periods, 1);
      expect(spendTime(clock, 75000, 30000).baseMs, 0);
    });

    test('초읽기 중 30초 안에 두면 줄지 않는다', () {
      const clock = SideClock(baseMs: 0, periods: 1, extensionsUsed: 0);
      expect(spendTime(clock, 29000, 30000).periods, 1);
    });

    test('시간패 시각은 기본 시간과 초읽기를 모두 쓰고 30초가 더 지난 때다', () {
      final game = _playingGame(startedAt: 5000000);
      expect(getTimeoutAt(game), 5000000 + 300000 + 4 * 30000);
    });

    test('시간패 시각이 지나면 차례인 쪽이 시간패로 진다', () {
      final game = _playingGame(startedAt: 5000000);
      final timeoutAt = getTimeoutAt(game);
      final before = applyDueEvents(game, timeoutAt - 1, drafts: const {}, connections: _bothConnected(timeoutAt - 1));
      expect(before.state.phase, GamePhase.playing);
      final ended = applyDueEvents(game, timeoutAt + 9999, drafts: const {}, connections: _bothConnected(timeoutAt));
      expect(ended.state.phase, GamePhase.finished);
      expect(ended.state.result?.winner, Side.han);
      expect(ended.state.result?.reason, GameEndReason.timeout);
      expect(ended.state.endedAt, timeoutAt);
      expect(getNextEventAt(ended), isNull);
    });
  });

  group('접속 끊김', () {
    const since = 5100000;

    DisconnectUpdate update(SideDisconnect current, List<Connection> connections, int now) {
      return updateDisconnect(current, connections, now: now, createdAt: _createdAt, limitMs: _limitMs);
    }

    test('연결되어 있으면 바꾸지 않는다', () {
      const current = SideDisconnect(usedMs: 1000, since: null);
      final result = update(current, [_active(activeSince: _createdAt, lastSeenAt: since)], since + 3000);
      expect(identical(result.disconnect, current), isTrue);
      expect(result.lossAt, isNull);
    });

    test('끊기면 가장 최근 lastSeenAt부터 세고 남은 허용 시간 뒤에 진다', () {
      final result = update(const SideDisconnect(usedMs: 4000, since: null), [
        _offline(activeSince: _createdAt, lastSeenAt: since - 9000),
        _offline(activeSince: _createdAt, lastSeenAt: since),
      ], since + 2000);
      expect(result.disconnect.since, since);
      expect(result.disconnect.usedMs, 4000);
      expect(result.lossAt, since + _limitMs - 4000);
    });

    test('다른 앱으로 넘어가거나 lastSeenAt이 오래되면 끊긴 것으로 본다', () {
      const background = Connection(online: true, foreground: false, activeSince: _createdAt, lastSeenAt: since);
      expect(update(const SideDisconnect(usedMs: 0, since: null), [background], since + 1000).disconnect.since, since);
      final stale = _active(activeSince: _createdAt, lastSeenAt: since);
      final staleMs = const Duration(seconds: presenceStaleSeconds).inMilliseconds;
      expect(update(const SideDisconnect(usedMs: 0, since: null), [stale], since + staleMs).disconnect.since, isNull);
      expect(
        update(const SideDisconnect(usedMs: 0, since: null), [stale], since + staleMs + 1).disconnect.since,
        since,
      );
    });

    test('연결 기록이 없거나 대국 전 기록이면 대국을 만든 시각부터 센다', () {
      expect(update(const SideDisconnect(usedMs: 0, since: null), [], since).disconnect.since, _createdAt);
      final old = _offline(activeSince: _createdAt - 9000, lastSeenAt: _createdAt - 5000);
      expect(update(const SideDisconnect(usedMs: 0, since: null), [old], since).disconnect.since, _createdAt);
    });

    test('돌아오면 끊긴 시간을 합계에 더한다', () {
      final result = update(const SideDisconnect(usedMs: 3000, since: since), [
        _active(activeSince: since + 7000, lastSeenAt: since + 9000),
      ], since + 9500);
      expect(result.disconnect.usedMs, 10000);
      expect(result.disconnect.since, isNull);
      expect(result.lossAt, isNull);
    });

    test('돌아왔다가 다시 끊긴 것을 서버가 못 봤어도 돌아온 동안은 빼고 센다', () {
      final result = update(const SideDisconnect(usedMs: 0, since: since), [
        _offline(activeSince: _createdAt, lastSeenAt: since),
        _offline(activeSince: since + 5000, lastSeenAt: since + 12000),
      ], since + 15000);
      expect(result.disconnect.usedMs, 5000);
      expect(result.disconnect.since, since + 12000);
      expect(result.lossAt, since + 12000 + _limitMs - 5000);
    });

    test('돌아오기 전에 합계가 허용 시간에 닿았으면 그 시각에 진다', () {
      const current = SideDisconnect(usedMs: 25000, since: since);
      final result = update(current, [_active(activeSince: since + 8000, lastSeenAt: since + 8000)], since + 8000);
      expect(identical(result.disconnect, current), isTrue);
      expect(result.lossAt, since + 5000);
    });

    test('끊긴 뒤 돌아온 연결 없이 다시 살아나면 끊긴 시간을 더하지 않는다', () {
      final result = update(const SideDisconnect(usedMs: 2000, since: since), [
        _active(activeSince: _createdAt, lastSeenAt: since + 20000),
      ], since + 20000);
      expect(result.disconnect.usedMs, 2000);
      expect(result.disconnect.since, isNull);
    });

    test('합계가 허용 시간에 닿으면 끊긴 쪽이 접속 끊김으로 지고 다음 판정을 그 시각에 예약한다', () {
      final game = _playingGame(startedAt: since - 1000);
      final connections = {
        Side.cho: [_active(activeSince: _createdAt, lastSeenAt: since + 1000)],
        Side.han: [_offline(activeSince: _createdAt, lastSeenAt: since)],
      };
      final marked = applyDueEvents(game, since + 1000, drafts: const {}, connections: connections);
      expect(marked.state.disconnect.han.since, since);
      expect(marked.state.phase, GamePhase.playing);
      expect(getNextEventAt(marked), since + _limitMs);
      expect(
        identical(applyDueEvents(marked, since + 2000, drafts: const {}, connections: connections), marked),
        isTrue,
      );

      final ended = applyDueEvents(marked, since + _limitMs + 3000, drafts: const {}, connections: connections);
      expect(ended.state.phase, GamePhase.finished);
      expect(ended.state.result?.reason, GameEndReason.disconnect);
      expect(ended.state.result?.winner, Side.cho);
      expect(ended.state.endedAt, since + _limitMs);
    });

    test('끊긴 동안에도 시계가 흘러 시간패가 먼저 올 수 있다', () {
      final game = _playingGame(startedAt: since);
      final timeoutAt = getTimeoutAt(game);
      // 초 차례에 초가 시간패 20초 전에 끊겼다.
      final connections = {
        Side.cho: [_offline(activeSince: _createdAt, lastSeenAt: timeoutAt - 20000)],
        Side.han: [_active(activeSince: _createdAt, lastSeenAt: timeoutAt + 60000)],
      };
      final ended = applyDueEvents(game, timeoutAt + 60000, drafts: const {}, connections: connections);
      expect(ended.state.result?.reason, GameEndReason.timeout);
      expect(ended.state.endedAt, timeoutAt);
    });

    test('상차림 중에도 센다', () {
      final connections = {
        Side.cho: [_active(activeSince: _createdAt, lastSeenAt: _startsAt + 1000)],
        Side.han: <Connection>[],
      };
      final marked = applyDueEvents(_newGame(), _startsAt + 1000, drafts: const {}, connections: connections);
      // 한은 대국을 만든 때부터 끊겨 있었고, 30초는 한의 상차림 마감(상대 찾음 3초 + 20초)보다 늦다.
      expect(marked.state.phase, GamePhase.setup);
      expect(marked.state.disconnect.han.since, _createdAt);
      final lost = applyDueEvents(marked, _createdAt + _limitMs, drafts: const {}, connections: connections);
      expect(lost.state.result?.reason, GameEndReason.disconnect);
      expect(lost.state.result?.winner, Side.cho);
      expect(lost.state.setup.han, defaultFormation);
      expect(lost.state.endedAt, _createdAt + _limitMs);
    });
  });

  group('수', () {
    test('수를 두면 시계를 넘기고 차례를 바꾼다', () {
      final game = _playingGame(startedAt: 5000000);
      final moved = playMove(game, Side.cho, 0, Move.parse('a4b4'), 5007000);
      expect(moved.moves.single.m, 'a4b4');
      expect(moved.moves.single.spentMs, 7000);
      expect(moved.state.turn, Side.han);
      expect(moved.state.turnStartedAt, 5007000);
      expect(moved.state.clock.cho.baseMs, 293000);
      expect(moved.state.clock.han.baseMs, 300000);
    });

    test('같은 수를 다시 보내면 바꾸지 않는다', () {
      final moved = playMove(_playingGame(), Side.cho, 0, Move.parse('a4b4'), _startsAt + 2000);
      expect(identical(playMove(moved, Side.cho, 0, Move.parse('a4b4'), _startsAt + 3000), moved), isTrue);
    });

    test('차례, 수 번호, 합법성을 확인한다', () {
      final game = _playingGame();
      final now = _startsAt + 2000;
      expect(() => playMove(game, Side.han, 0, Move.parse('a7b7'), now), _rejectedWith(GameErrorCode.notYourTurn));
      expect(() => playMove(game, Side.cho, 1, Move.parse('a4b4'), now), _rejectedWith(GameErrorCode.moveConflict));
      expect(() => playMove(game, Side.cho, 0, Move.parse('a1a9'), now), _rejectedWith(GameErrorCode.illegalMove));
      final moved = playMove(game, Side.cho, 0, Move.parse('a4b4'), now);
      expect(() => playMove(moved, Side.cho, 0, Move.parse('e4f4'), now), _rejectedWith(GameErrorCode.moveConflict));
      expect(
        () => playMove(_newGame(), Side.cho, 0, Move.parse('a4b4'), now),
        _rejectedWith(GameErrorCode.notYourTurn),
      );
    });

    test('양쪽이 연속으로 한수쉼을 하면 점수로 끝낸다', () {
      final game = _playingGame();
      final once = playMove(game, Side.cho, 0, Move.pass, _startsAt + 2000);
      final ended = playMove(once, Side.han, 1, Move.pass, _startsAt + 3000);
      expect(ended.state.phase, GamePhase.finished);
      expect(ended.state.result?.reason, GameEndReason.consecutivePasses);
      expect(ended.state.result?.winner, Side.han);
      expect(ended.state.result?.hanScore, 73.5);
      expect(ended.state.endedAt, _startsAt + 3000);
      expect(() => playMove(ended, Side.cho, 2, Move.pass, _startsAt + 4000), _rejectedWith(GameErrorCode.gameOver));
    });
  });

  group('기권', () {
    test('대국 중 기권하면 상대가 이긴다', () {
      final ended = resign(_playingGame(), Side.cho, _startsAt + 5000);
      expect(ended.state.result?.winner, Side.han);
      expect(ended.state.result?.reason, GameEndReason.resignation);
      expect(() => resign(ended, Side.han, _startsAt + 6000), _rejectedWith(GameErrorCode.gameOver));
    });

    test('상차림 중에도 기권할 수 있고 기본 상차림 점수로 기록한다', () {
      final ended = resign(_newGame(), Side.han, _startsAt + 1000);
      expect(ended.state.result?.winner, Side.cho);
      expect(ended.state.result?.choScore, 72);
      expect(getInitialPosition(ended).fen, createInitialPosition(cho: defaultFormation, han: defaultFormation).fen);
    });
  });

  test('대국자가 아니면 notPlayer', () {
    expect(requirePlayerSide(_newGame(), 'han-uid'), Side.han);
    expect(() => requirePlayerSide(_newGame(), 'someone'), _rejectedWith(GameErrorCode.notPlayer));
  });

  test('RTDB에 쓴 JSON을 다시 읽으면 같은 대국이다', () {
    final game = playMove(_playingGame(), Side.cho, 0, Move.parse('a4b4'), _startsAt + 2000);
    final json = game.toJson();
    expect(json.containsKey('rematch'), isFalse);
    expect(ActiveGame.fromJson(json).toJson(), json);
  });

  group('다시 두기', () {
    ActiveGame finishedGame({GameMode mode = GameMode.quick, int rematchCount = 0}) {
      final created = createActiveGame(
        mode: mode,
        rated: mode == GameMode.quick,
        listed: true,
        players: const GamePlayers(
          cho: GamePlayer(uid: 'cho-uid', nickname: '초사람', rankLevel: 1),
          han: GamePlayer(uid: 'han-uid', nickname: '한사람', rankLevel: 2),
        ),
        timeControl: defaultTimeControl,
        disconnectLimitMs: 30000,
        introMs: _introMs,
        now: _createdAt,
        rematchCount: rematchCount,
      );
      return resign(created, Side.cho, _startsAt + 100);
    }

    ActiveGame press(ActiveGame game, Side side, {bool opponentPresent = true, int limit = 5}) =>
        pressRematch(game, side, quickRematchLimit: limit, opponentPresent: opponentPresent, newGameId: 'new-game');

    test('한쪽이 누르면 기다리고 두 쪽이 모두 누르면 새 대국 ID를 정한다', () {
      final first = press(finishedGame(), Side.han);
      expect(first.rematch?.han, isTrue);
      expect(first.rematch?.gameId, isNull);

      final both = press(first, Side.cho);
      expect(both.rematch?.cho, isTrue);
      expect(both.rematch?.gameId, 'new-game');

      // 이미 정해졌으면 다시 눌러도 그대로다.
      expect(identical(press(both, Side.han), both), isTrue);
    });

    test('상대가 앱에 없으면 취소한다', () {
      final cancelled = press(finishedGame(), Side.han, opponentPresent: false);
      expect(cancelled.rematch?.cancelled, isTrue);
      expect(cancelled.rematch?.han, isNull);
      expect(() => press(cancelled, Side.cho), _rejectedWith(GameErrorCode.rematchUnavailable));
    });

    test('끝나지 않은 대국과 횟수에 닿은 빠른 대국은 거절한다', () {
      expect(() => press(_playingGame(), Side.cho), _rejectedWith(GameErrorCode.rematchUnavailable));
      expect(() => press(finishedGame(rematchCount: 5), Side.cho), _rejectedWith(GameErrorCode.rematchUnavailable));
      // 빠른 대국이 아니면 횟수를 세지 않는다.
      expect(press(finishedGame(mode: GameMode.challenge, rematchCount: 9), Side.cho).rematch?.cho, isTrue);
    });

    test('횟수에 닿을 대국은 처음부터 막아 둔다', () {
      final blocked = createActiveGame(
        mode: GameMode.quick,
        rated: true,
        listed: true,
        players: _newGame().meta.players,
        timeControl: defaultTimeControl,
        disconnectLimitMs: 30000,
        introMs: _introMs,
        now: _createdAt,
        rematchOf: 'old',
        rematchCount: 5,
        rematchBlocked: true,
      );
      expect(blocked.rematch?.blocked, isTrue);
      expect(blocked.meta.rematchOf, 'old');
      expect(
        () => press(resign(blocked, Side.han, _startsAt + 100), Side.cho),
        _rejectedWith(GameErrorCode.rematchUnavailable),
      );
    });

    test('결과 화면을 나가면 정해지기 전의 다시 두기를 취소한다', () {
      final pressed = press(finishedGame(), Side.han);
      expect(cancelRematch(pressed).rematch?.cancelled, isTrue);
      final both = press(pressed, Side.cho);
      expect(identical(cancelRematch(both), both), isTrue);
      expect(cancelRematch(_playingGame()).rematch, isNull);
    });

    test('새 대국을 만들지 못하면 ID를 지우고 취소한다', () {
      final both = press(press(finishedGame(), Side.han), Side.cho);
      final failed = failRematch(both);
      expect(failed.rematch?.gameId, isNull);
      expect(failed.rematch?.cancelled, isTrue);
      expect(failed.rematch?.cho, isTrue);
    });

    test('초와 한을 바꾸고 닉네임과 급수는 지금 값으로 바꾼다', () {
      final players = getRematchPlayers(finishedGame(), {
        'cho-uid': const GamePlayer(uid: 'cho-uid', nickname: '초사람', rankLevel: 3),
      });
      expect(players.cho.uid, 'han-uid');
      expect(players.han.uid, 'cho-uid');
      expect(players.han.rankLevel, 3);
      expect(players.cho.rankLevel, 2);
    });
  });
}
