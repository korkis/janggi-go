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

      review.toggleTrial();
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

      review.toggleTrial();
      expect(review.trying, isFalse);
      expect(review.ply, 1);
      expect(review.position, record.positions[1]);
      expect(review.targets, isEmpty);
    });

    test('놓아보기를 끈 상태에서는 판을 눌러도 아무것도 하지 않는다', () {
      final review = ReviewManager(record: _record());
      review.tapSquare(Square.parse('a7'));

      expect(review.selected, isNull);
    });
  });
}
