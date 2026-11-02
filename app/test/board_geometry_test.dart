import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/widgets/board/board_geometry.dart';

void main() {
  group('BoardGeometry', () {
    const size = Size(BoardGeometry.widthCells * 40, BoardGeometry.heightCells * 40);

    test('초가 아래면 a1이 왼쪽 아래, i10이 오른쪽 위다', () {
      final geometry = BoardGeometry(size, flipped: false);

      expect(geometry.cell, closeTo(40, 1e-9));
      expect(geometry.centerOf(Square.parse('a1')), offsetMoreOrLessEquals(const Offset(26, 26 + 9 * 40)));
      expect(geometry.centerOf(Square.parse('i10')), offsetMoreOrLessEquals(const Offset(26 + 8 * 40, 26)));
    });

    test('판을 돌리면 한이 아래다', () {
      final geometry = BoardGeometry(size, flipped: true);

      expect(geometry.centerOf(Square.parse('i10')), offsetMoreOrLessEquals(const Offset(26, 26 + 9 * 40)));
    });

    test('교차점 둘레 칸 전체를 누르는 영역으로 잡는다', () {
      for (final flipped in [false, true]) {
        final geometry = BoardGeometry(size, flipped: flipped);
        for (final square in Square.all) {
          final center = geometry.centerOf(square);
          expect(geometry.squareAt(center), square);
          expect(geometry.squareAt(center + const Offset(19, -19)), square);
        }
      }
    });

    test('판 가장자리 바깥은 null이다', () {
      final geometry = BoardGeometry(size, flipped: false);

      expect(geometry.squareAt(const Offset(1, 1)), isNull);
    });
  });
}
