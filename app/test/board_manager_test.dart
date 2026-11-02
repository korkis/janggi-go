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

    test('판 돌리기', () {
      final board = BoardManager(initialPosition: _standardPosition());
      board.toggleFlipped();

      expect(board.flipped, isTrue);
    });
  });
}
