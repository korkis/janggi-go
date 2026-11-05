import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/managers/review_manager.dart';

Game _record() => Game.replay(
  createInitialPosition(cho: Formation.horseElephantHorseElephant, han: Formation.horseElephantHorseElephant),
  ['c4c5', 'c7c6', 'c5c6'].map(Move.parse),
);

void main() {
  group('ReviewManager', () {
    test('끝난 국면에서 시작하고 처음, 이전, 다음, 끝으로 움직인다', () {
      final record = _record();
      final review = ReviewManager(record: record);
      expect(review.ply, 3);
      expect(review.position, record.position);
      expect(review.lastMove, Move.parse('c5c6'));

      review.goPrevious();
      expect(review.ply, 2);
      expect(review.position, record.positions[2]);
      expect(review.lastMove, Move.parse('c7c6'));

      review.goFirst();
      expect(review.ply, 0);
      expect(review.lastMove, isNull);

      review
        ..goPrevious()
        ..goNext();
      expect(review.ply, 1);

      review.goLast();
      expect(review.ply, 3);
    });

    test('범위를 벗어난 위치는 처음이나 끝으로 맞춘다', () {
      final review = ReviewManager(record: _record());

      review.goTo(-5);
      expect(review.ply, 0);
      review.goTo(99);
      expect(review.ply, 3);
    });

    test('놓아보기는 지금 위치에서 이어 두고, 끄면 원래 기보 위치로 돌아간다', () {
      final record = _record();
      final review = ReviewManager(record: record)..goTo(1);

      review.startTrial();
      expect(review.trying, isTrue);
      review
        ..tapSquare(Square.parse('a7'))
        ..tapSquare(Square.parse('a6'));
      expect(review.trialMoveCount, 1);
      expect(review.lastMove, Move.parse('a7a6'));
      expect(review.position.pieceAt(Square.parse('a6')), const Piece(Side.han, PieceType.soldier));

      // 놓아보기 중에는 기보 위치를 옮기지 않는다.
      review.goNext();
      expect(review.ply, 1);

      review.endTrial();
      expect(review.trying, isFalse);
      expect(review.ply, 1);
      expect(review.position, record.positions[1]);
      expect(review.targets, isEmpty);
    });

    test('놓아보기 중에는 처음, 이전, 다음이 놓아 본 수를 오가고 수는 남는다', () {
      final record = _record();
      final review = ReviewManager(record: record)..goTo(1);
      review.startTrial();
      expect(review.canGoBack, isFalse);
      expect(review.canGoForward, isFalse);

      review
        ..tapSquare(Square.parse('a7'))
        ..tapSquare(Square.parse('a6'))
        ..tapSquare(Square.parse('a4'))
        ..tapSquare(Square.parse('a5'));
      expect(review.trialMoveCount, 2);
      expect(review.canGoBack, isTrue);
      expect(review.canGoForward, isFalse);

      review.goPrevious();
      expect(review.trialMoveCount, 1);
      expect(review.lastMove, Move.parse('a7a6'));
      expect(review.canGoForward, isTrue);

      review.goFirst();
      expect(review.trialMoveCount, 0);
      expect(review.position, record.positions[1]);

      review
        ..goNext()
        ..goNext();
      expect(review.trialMoveCount, 2);
      expect(review.lastMove, Move.parse('a4a5'));
      review.goNext();
      expect(review.trialMoveCount, 2);
    });

    test('뒤로 간 자리에서 다른 수를 두면 그 뒤의 수를 새 수로 바꾸고, 끝내면 놓아 본 수를 지운다', () {
      final record = _record();
      final review = ReviewManager(record: record)..goTo(1);
      review
        ..startTrial()
        ..tapSquare(Square.parse('a7'))
        ..tapSquare(Square.parse('a6'))
        ..tapSquare(Square.parse('a4'))
        ..tapSquare(Square.parse('a5'))
        ..goPrevious();

      // 같은 수를 다시 두면 그 뒤의 수가 남는다.
      review
        ..tapSquare(Square.parse('a4'))
        ..tapSquare(Square.parse('a5'))
        ..goFirst()
        ..goNext();
      expect(review.canGoForward, isTrue);

      review
        ..tapSquare(Square.parse('e4'))
        ..tapSquare(Square.parse('e5'));
      expect(review.trialMoveCount, 2);
      expect(review.lastMove, Move.parse('e4e5'));
      expect(review.canGoForward, isFalse);
      review.goPrevious();
      review.goNext();
      expect(review.lastMove, Move.parse('e4e5'));

      review.endTrial();
      expect(review.position, record.positions[1]);
      review.startTrial();
      expect(review.trialMoveCount, 0);
      expect(review.canGoForward, isFalse);
    });

    test('놓아보기를 끈 상태에서는 판을 눌러도 아무것도 하지 않는다', () {
      final review = ReviewManager(record: _record());
      review.tapSquare(Square.parse('a7'));

      expect(review.selected, isNull);
    });
  });
}
