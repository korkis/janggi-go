import 'package:janggi_core/janggi_core.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

Position _start() => createInitialPosition(
      cho: Formation.horseElephantHorseElephant,
      han: Formation.horseElephantHorseElephant,
    );

void main() {
  group('반복수 기본 제한', () {
    test('같은 국면이 3번째로 나오게 하는 수는 둘 수 없다', () {
      final game = Game.replay(_start(), ['a1a2', 'a10a9', 'a2a1', 'a9a10', 'a1a2', 'a10a9', 'a2a1'].map(Move.parse));
      // a9a10을 두면 처음 국면이 3번째로 나온다. 양쪽 모두 공격 없이 오가므로 기본 제한대로 금지한다.
      expect(game.position.isLegal(mv('a9a10')), isTrue);
      expect(game.isLegal(mv('a9a10')), isFalse);
      expect(game.legalMoves(), isNot(contains(mv('a9a10'))));
      expect(game.legalMoves(), contains(mv('a9a8')));
      expect(() => game.play(mv('a9a10')), throwsArgumentError);
    });

    test('2번째로 나오게 하는 수는 둘 수 있다', () {
      final game = Game.replay(_start(), ['a1a2', 'a10a9', 'a2a1'].map(Move.parse));
      expect(game.isLegal(mv('a9a10')), isTrue);
    });

    test('한수쉼도 같은 국면을 3번째로 만들면 둘 수 없다', () {
      final game = Game.replay(_start(), ['a1a2', 'pass', 'a2a1', 'pass', 'a1a2', 'pass', 'a2a1'].map(Move.parse));
      expect(game.isLegal(Move.pass), isFalse);
    });
  });

  group('반복수: 공격하는 쪽이 피한다', () {
    // c9 한 차는 b9 초 마의 멱을 막고 있어 움직이면 d10 한 궁이 장군을 받는다. 그래서 차는 c1 초 포를 잡을 수 없다.
    const base = '3k5/1Nr6/9/1p7/9/9/3P5/9/5K3/2C6 w';

    test('예시 1: 졸과 병을 번갈아 옆으로 옮기면 초만 반복 제한에 걸린다', () {
      // 초 d4c4: 포가 졸을 다리로 차를 노린다. 한 b7c7: 병으로 막는다.
      // 초 c4d4: 졸을 빼 병을 다리로 다시 노린다. 한 c7b7: 병을 빼 피한다.
      final game = replay(base, 'd4c4 b7c7 c4d4 c7b7 d4c4 b7c7 c4d4');
      // 한의 c7b7은 처음 국면을 3번째로 만들지만 피하는 수라서 둘 수 있다.
      expect(game.isLegal(mv('c7b7')), isTrue);
      final afterEvasion = game.play(mv('c7b7'));
      expect(afterEvasion.positions.where((position) => position == afterEvasion.position).length, 3);
      // 초의 d4c4는 새 공격수로 같은 국면을 3번째로 만들므로 금지수다.
      expect(afterEvasion.position.isLegal(mv('d4c4')), isTrue);
      expect(afterEvasion.isLegal(mv('d4c4')), isFalse);
      expect(afterEvasion.isOver, isFalse);
      expect(afterEvasion.legalMoves(), isNotEmpty);
    });

    test('예시 2: 포가 졸을 넘어 앞뒤로 오가면 처음 자리가 아니어도 초가 제한된다', () {
      // 초 포가 c1에서 졸을 다리로 차를 노리는 상태에서 한 차례로 시작한다.
      const start = '3k5/1Nr6/9/1p7/9/9/2P6/9/5K3/2C6 b';
      final game = replay(start, 'b7c7 c1c5 c7b7 c5c3 b7c7 c3c5 c7b7 c5c3 b7c7');
      // c3c5는 포가 졸 앞에서 병을 다리로 차를 노리는 국면을 3번째로 만든다.
      expect(game.position.isLegal(mv('c3c5')), isTrue);
      expect(game.isLegal(mv('c3c5')), isFalse);
      // 같은 공격이라도 처음 나오는 국면을 만드는 c3c6은 둘 수 있다.
      expect(game.isLegal(mv('c3c6')), isTrue);
    });

    test('피하는 쪽이 새 공격도 하면 양쪽 모두 공격하는 반복이라 기본 제한을 적용한다', () {
      // 병이 c5로 들어와 막으면 c4 졸을 노리게 되므로 한의 수도 새 공격수다.
      const mixed = '3k5/1Nr6/9/9/9/1p7/3P5/9/5K3/2C6 w';
      final game = replay(mixed, 'd4c4 b5c5 c4d4 c5b5 d4c4 b5c5 c4d4');
      expect(game.position.isLegal(mv('c5b5')), isTrue);
      expect(game.isLegal(mv('c5b5')), isFalse);
    });

    test('반복장군에서 장군을 받는 쪽은 계속 피하고 장군을 거는 쪽이 제한된다', () {
      // 초 차가 a9·a10을 오가며 장군을 걸고, 한 궁이 d9·d10을 오가며 피한다.
      final game = replay('R8/3k5/9/9/9/9/9/9/9/5K3 w', 'a10a9 d9d10 a9a10 d10d9 a10a9 d9d10 a9a10');
      expect(game.isLegal(mv('d10d9')), isTrue);
      final afterEvasion = game.play(mv('d10d9'));
      expect(afterEvasion.positions.where((position) => position == afterEvasion.position).length, 3);
      expect(afterEvasion.position.isLegal(mv('a10a9')), isTrue);
      expect(afterEvasion.isLegal(mv('a10a9')), isFalse);
    });
  });

  group('한수쉼', () {
    test('양쪽이 연속으로 한수쉼을 하면 점수로 판정한다', () {
      final game = Game.start(_start()).play(Move.pass).play(Move.pass);
      expect(game.isOver, isTrue);
      expect(
        game.result,
        const GameResult(winner: Side.han, reason: GameEndReason.consecutivePasses, choScore: 72, hanScore: 73.5),
      );
      expect(game.legalMoves(), isEmpty);
      expect(() => game.play(mv('a1a2')), throwsArgumentError);
    });

    test('한쪽만 한수쉼을 하고 상대가 수를 두면 계속한다', () {
      final game = Game.replay(_start(), ['pass', 'a7a6', 'pass'].map(Move.parse));
      expect(game.isOver, isFalse);
    });
  });

  group('외통', () {
    test('장군을 벗어날 수 있는 수가 없으면 장군을 받은 쪽이 진다', () {
      final game = replay('3k5/R8/9/9/9/9/9/9/9/1R3K3 w', 'b1b10');
      expect(game.result?.winner, Side.cho);
      expect(game.result?.reason, GameEndReason.checkmate);
      expect(game.result?.reason.isScoreJudgment, isFalse);
    });

    test('장군이어도 벗어날 수가 있으면 계속한다', () {
      final game = replay('3k5/9/9/9/9/9/9/9/9/1R3K3 w', 'b1b10');
      expect(game.position.isInCheck(Side.han), isTrue);
      expect(game.isOver, isFalse);
    });
  });

  group('둘 수 있는 수가 없음', () {
    test('장군이 아닌데 수도 한수쉼도 둘 수 없으면 점수로 판정한다', () {
      // 한 궁은 d10에서 갈 곳이 모두 초 차에 막혀 있어 한수쉼만 할 수 있다.
      // 초가 궁을 f1과 f2로 오가면 한의 한수쉼이 결국 같은 국면을 3번째로 만든다.
      final game = replay('3k5/R8/9/9/9/9/9/9/9/4RK3 w', 'f1f2 pass f2f1 pass f1f2 pass f2f1');
      expect(game.position.isInCheck(Side.han), isFalse);
      expect(
        game.result,
        const GameResult(winner: Side.cho, reason: GameEndReason.noLegalMoves, choScore: 26, hanScore: 1.5),
      );
    });
  });

  group('200수 제한', () {
    test('한수쉼을 포함해 총 200수가 되면 점수로 판정한다', () {
      var game = Game.start(_start());
      while (game.moves.length < Game.maxMoves - 1) {
        game = game.play(_quietNewMove(game));
      }
      expect(game.isOver, isFalse);
      game = game.play(Move.pass);
      expect(game.moves.length, 200);
      expect(game.result?.reason, GameEndReason.moveLimit);
      expect(game.result?.reason.isScoreJudgment, isTrue);
    });
  });

  group('기권과 시간패', () {
    test('기권한 쪽이 진다', () {
      final game = Game.start(_start()).resign(Side.cho);
      expect(
        game.result,
        const GameResult(winner: Side.han, reason: GameEndReason.resignation, choScore: 72, hanScore: 73.5),
      );
      expect(() => game.resign(Side.han), throwsStateError);
    });

    test('시간을 모두 쓴 쪽이 진다', () {
      final game = Game.start(_start()).play(mv('a4a5')).timeout(Side.han);
      expect(game.result?.winner, Side.cho);
      expect(game.result?.reason, GameEndReason.timeout);
      expect(game.result?.reason.isScoreJudgment, isFalse);
    });
  });

  group('점수 판정', () {
    test('남은 기물 점수에 한의 덤 1.5점을 더해 높은 쪽이 이긴다', () {
      // 초 차 하나를 잃어 초 59점, 한 73.5점이다.
      final lost = Position.fromFen('rbna1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/1NBA1ANBR w');
      expect(lost.score(Side.cho), 59);
      final game = Game.start(lost).play(Move.pass).play(Move.pass);
      expect(game.result?.winner, Side.han);
      // 한이 차와 포를 잃으면 한 53.5점으로 초 72점보다 낮다.
      final hanLost = Position.fromFen('1bna1abnr/4k4/1c7/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ANBR w');
      final hanLostGame = Game.start(hanLost).play(Move.pass).play(Move.pass);
      expect(hanLostGame.result?.winner, Side.cho);
      expect(hanLostGame.result?.hanScore, 53.5);
    });
  });

  test('처음 국면과 수 목록으로 같은 대국을 재생한다', () {
    final game = Game.replay(_start(), ['a4a5', 'i7i6', 'b1c3'].map(Move.parse));
    expect(game.moves.map((move) => move.toString()), ['a4a5', 'i7i6', 'b1c3']);
    expect(game.positions.length, 4);
    expect(game.positions.first, _start());
    expect(Game.replay(game.initialPosition, game.moves).position, game.position);
    expect(() => game.moves.add(Move.pass), throwsUnsupportedError);
  });
}

/// 잡지 않고 장군도 걸지 않으면서 처음 나오는 국면을 만드는 수. 수 제한 테스트용이다.
Move _quietNewMove(Game game) {
  for (final move in game.legalMoves()) {
    if (move.isPass || game.position.pieceAt(move.to!) != null) {
      continue;
    }
    final next = game.position.play(move);
    if (next.isInCheck(next.turn) || game.positions.contains(next)) {
      continue;
    }
    return move;
  }
  throw StateError('둘 수 있는 조용한 수가 없다');
}
