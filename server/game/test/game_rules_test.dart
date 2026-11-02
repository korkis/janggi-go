import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo_game/config.dart';
import 'package:janggigo_game/http/callable.dart';
import 'package:janggigo_game/models/active_game.dart';
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
      );
      expect(game.state.setup.han, Formation.horseElephantElephantHorse);
      expect(game.state.setup.cho, defaultFormation);
      expect(game.state.phase, GamePhase.playing);
      // 초의 마감은 한의 마감 + 20초이고, 초의 차례는 지금이 아니라 그 마감부터 시작한다.
      expect(game.state.turnStartedAt, hanDeadline + _setupMs);
    });

    test('마감 전에는 바꾸지 않는다', () {
      final game = _newGame();
      expect(identical(applyDueEvents(game, _startsAt + _setupMs - 1, drafts: const {}), game), isTrue);
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
      expect(applyDueEvents(game, timeoutAt - 1, drafts: const {}).state.phase, GamePhase.playing);
      final ended = applyDueEvents(game, timeoutAt + 9999, drafts: const {});
      expect(ended.state.phase, GamePhase.finished);
      expect(ended.state.result?.winner, Side.han);
      expect(ended.state.result?.reason, GameEndReason.timeout);
      expect(ended.state.endedAt, timeoutAt);
      expect(getNextEventAt(ended), isNull);
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
}
