import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/managers/board_manager.dart';

/// 초가 i1i10으로 외통을 거는 국면. 한 궁 e10, 초 차 a9·i1, 초 궁 e2.
const _mateInOneFen = '4k4/R8/9/9/9/9/9/9/4K4/8R w';

Position _standardPosition() =>
    createInitialPosition(cho: Formation.horseElephantHorseElephant, han: Formation.horseElephantHorseElephant);

void main() {
  group('BoardManager', () {
    test('차례인 쪽 기물을 누르면 고르고 갈 수 있는 자리를 구한다', () {
      final board = BoardManager(initialPosition: _standardPosition());
      board.tapSquare(Square.parse('a4'));

      expect(board.selected, Square.parse('a4'));
      expect(board.targets, {Square.parse('a5'), Square.parse('b4')});
    });

    test('차례가 아닌 쪽 기물은 고르지 않는다', () {
      final board = BoardManager(initialPosition: _standardPosition());
      board.tapSquare(Square.parse('a7'));

      expect(board.selected, isNull);
      expect(board.targets, isEmpty);
    });

    test('고른 기물을 다시 누르면 고르기를 푼다', () {
      final board = BoardManager(initialPosition: _standardPosition());
      board
        ..tapSquare(Square.parse('a4'))
        ..tapSquare(Square.parse('a4'));

      expect(board.selected, isNull);
    });

    test('갈 수 있는 자리를 누르면 수를 두고 차례를 넘긴다', () {
      final board = BoardManager(initialPosition: _standardPosition());
      board
        ..tapSquare(Square.parse('a4'))
        ..tapSquare(Square.parse('a5'));

      expect(board.lastMove, Move.parse('a4a5'));
      expect(board.turn, Side.han);
      expect(board.dimmedSide, Side.cho);
      expect(board.selected, isNull);
      expect(board.moveCount, 1);
    });

    test('양쪽이 연속으로 한수쉼을 하면 점수로 끝난다', () {
      final board = BoardManager(initialPosition: _standardPosition());
      board.pass();
      expect(board.hasPassedLast(Side.cho), isTrue);
      expect(board.hasPassedLast(Side.han), isFalse);
      expect(board.isOver, isFalse);

      board.pass();
      expect(board.isOver, isTrue);
      expect(board.result!.reason, GameEndReason.consecutivePasses);
      expect(board.result!.winner, Side.han);
      expect(board.dimmedSide, isNull);
    });

    test('기권하면 차례인 쪽이 진다', () {
      final board = BoardManager(initialPosition: _standardPosition());
      board.resign();

      expect(board.result!.reason, GameEndReason.resignation);
      expect(board.result!.winner, Side.han);
    });

    test('외통이면 끝나고 더는 둘 수 없다', () {
      final board = BoardManager(initialPosition: Position.fromFen(_mateInOneFen));
      board
        ..tapSquare(Square.parse('i1'))
        ..tapSquare(Square.parse('i10'));

      expect(board.isOver, isTrue);
      expect(board.result!.reason, GameEndReason.checkmate);
      expect(board.result!.winner, Side.cho);
      expect(board.canPass, isFalse);
      expect(() => board.pass(), throwsStateError);
    });

    test('장군을 받은 쪽을 알려주고 한수쉼을 막는다', () {
      // 초 차가 e1에서 세로줄로 한 궁 e10을 노린다. 한은 d10으로 피할 수 있다.
      final board = BoardManager(initialPosition: Position.fromFen('4k4/9/9/9/9/9/9/9/3K5/4R4 b'));

      expect(board.checkedSide, Side.han);
      expect(board.canPass, isFalse);
    });
  });

  group('둘 수 없는 수를 눌렀을 때', () {
    // c9 한 차는 b9 초 마의 멱을 막고 있어 움직이면 d10 한 궁이 장군을 받는다.
    const pinnedFen = '3k5/1Nr6/9/1p7/9/9/3P5/9/5K3/2C6 b';
    // a9 초 차가 d9 한 궁에 장군을 걸었다. i8 병은 어디로 가도 막지 못한다.
    const checkedFen = '9/R2k5/8p/9/9/9/9/9/9/5K3 b';

    test('두면 궁이 장군을 받는 자리는 기물을 고른 채로 이유를 남긴다', () {
      final board = BoardManager(initialPosition: Position.fromFen(pinnedFen));
      board.tapSquare(Square.parse('c9'));
      // 멱을 막던 차가 그 마를 잡는 수만 둘 수 있다.
      expect(board.targets, {Square.parse('b9')});
      expect(board.rejectedTap, isNull);

      board.tapSquare(Square.parse('c8'));
      expect(board.rejectedTap?.reason, MoveRejection.exposesGeneral);
      expect(board.selected, Square.parse('c9'));
      expect(board.moveCount, 0);
    });

    test('같은 자리를 다시 누르면 안내를 새로 띄운다', () {
      final board = BoardManager(initialPosition: Position.fromFen(pinnedFen));
      board.tapSquare(Square.parse('c9'));
      board.tapSquare(Square.parse('c8'));
      final first = board.rejectedTap;
      board.tapSquare(Square.parse('c8'));
      expect(board.rejectedTap, isNot(same(first)));
    });

    test('규칙으로도 못 가는 자리는 안내 없이 고르기를 푼다', () {
      final board = BoardManager(initialPosition: Position.fromFen(pinnedFen));
      board.tapSquare(Square.parse('c9'));
      board.tapSquare(Square.parse('c8'));
      board.tapSquare(Square.parse('e8'));
      expect(board.rejectedTap, isNull);
      expect(board.selected, isNull);
    });

    test('장군을 막지 못하는 자리는 장군을 막아야 한다는 이유를 남긴다', () {
      final board = BoardManager(initialPosition: Position.fromFen(checkedFen));
      board.tapSquare(Square.parse('d9'));
      expect(board.rejectedTap, isNull);
      board.tapSquare(Square.parse('e9'));
      expect(board.rejectedTap?.reason, MoveRejection.mustStopCheck);
      expect(board.selected, Square.parse('d9'));
    });

    test('장군 상태에서 갈 곳이 없는 기물을 눌러도 이유를 남기고, 둘 수 있는 수를 두면 지운다', () {
      final board = BoardManager(initialPosition: Position.fromFen(checkedFen));
      board.tapSquare(Square.parse('i8'));
      expect(board.rejectedTap?.reason, MoveRejection.mustStopCheck);
      expect(board.selected, Square.parse('i8'));

      board.tapSquare(Square.parse('d9'));
      expect(board.rejectedTap, isNull);
      board.tapSquare(Square.parse('d10'));
      expect(board.rejectedTap, isNull);
      expect(board.moveCount, 1);
    });

    test('반복수 금지 자리는 반복수라는 이유를 남긴다', () {
      final game = Game.replay(
        _standardPosition(),
        ['a1a2', 'a10a9', 'a2a1', 'a9a10', 'a1a2', 'a10a9', 'a2a1'].map(Move.parse),
      );
      final board = BoardManager.fromGame(game);
      board.tapSquare(Square.parse('a9'));
      board.tapSquare(Square.parse('a10'));
      expect(board.rejectedTap?.reason, MoveRejection.repetition);
      expect(board.selected, Square.parse('a9'));
    });

    test('내 차례가 아니면 이유를 남기지 않는다', () {
      final game = Game.start(Position.fromFen(checkedFen));
      final board = BoardManager.fromGame(game, player: Side.cho);
      board.tapSquare(Square.parse('i8'));
      expect(board.rejectedTap, isNull);
    });

    test('서버 상태로 국면이 바뀌면 이유를 지운다', () {
      final game = Game.start(Position.fromFen(pinnedFen));
      final board = BoardManager.fromGame(game, player: Side.han);
      board.tapSquare(Square.parse('c9'));
      board.tapSquare(Square.parse('c8'));
      expect(board.rejectedTap, isNotNull);

      board.syncGame(game);
      expect(board.rejectedTap, isNotNull);
      board.syncGame(game.play(Move.pass));
      expect(board.rejectedTap, isNull);
    });
  });
}
