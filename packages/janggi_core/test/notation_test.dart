import 'package:janggi_core/janggi_core.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('좌표', () {
    test('세로줄 a~i, 가로줄 1~10을 읽고 쓴다', () {
      expect(sq('a1').file, 0);
      expect(sq('a1').rank, 0);
      expect(sq('i10').file, 8);
      expect(sq('i10').rank, 9);
      expect(sq('e2').toString(), 'e2');
      expect(sq('a10').toString(), 'a10');
      expect(Square(4, 8), sq('e9'));
    });

    test('잘못된 칸 표기는 거부한다', () {
      for (final text in ['j1', 'a0', 'a11', 'A1', 'e', '1e', 'e01']) {
        expect(() => Square.parse(text), throwsFormatException, reason: text);
      }
    });
  });

  group('수', () {
    test('출발 칸과 도착 칸을 붙여 쓴다', () {
      expect(mv('b1c3'), Move(sq('b1'), sq('c3')));
      expect(mv('a10a8'), Move(sq('a10'), sq('a8')));
      expect(mv('a1a10'), Move(sq('a1'), sq('a10')));
      expect(mv('e7e6').toString(), 'e7e6');
      expect(mv('a10a8').toString(), 'a10a8');
    });

    test('한수쉼은 pass다', () {
      expect(mv('pass'), Move.pass);
      expect(Move.pass.isPass, isTrue);
      expect(Move.pass.toString(), 'pass');
    });

    test('잘못된 수 표기는 거부한다', () {
      for (final text in ['', 'b1', 'b1c', 'b1c11', 'PASS', 'b1-c3', 'j1a1']) {
        expect(() => Move.parse(text), throwsFormatException, reason: text);
      }
    });
  });

  group('국면 문자열', () {
    const start = 'rnba1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR w';

    test('가로줄 10부터 1까지 읽고 같은 문자열로 쓴다', () {
      final position = Position.fromFen(start);
      expect(position.pieceAt(sq('e2')), const Piece(Side.cho, PieceType.king));
      expect(position.pieceAt(sq('e9')), const Piece(Side.han, PieceType.king));
      expect(position.pieceAt(sq('b10')), const Piece(Side.han, PieceType.horse));
      expect(position.pieceAt(sq('c1')), const Piece(Side.cho, PieceType.elephant));
      expect(position.pieceAt(sq('h3')), const Piece(Side.cho, PieceType.cannon));
      expect(position.pieceAt(sq('e5')), isNull);
      expect(position.turn, Side.cho);
      expect(position.fen, start);
    });

    test('차례는 초가 w, 한이 b다', () {
      expect(Position.fromFen('4k4/9/9/9/9/9/9/9/4K4/9 b').turn, Side.han);
      expect(Position.fromFen('4k4/9/9/9/9/9/9/9/4K4/9 b').fen, '4k4/9/9/9/9/9/9/9/4K4/9 b');
    });

    test('잘못된 국면 문자열은 거부한다', () {
      for (final fen in [
        'rnba1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4 w',
        'rnba1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR',
        'rnba1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR x',
        'rnba1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABN w',
        'rnba2abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR w',
        'rnbx1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR w',
        'rnba0abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR w',
        '$start - - 0 1',
      ]) {
        expect(() => Position.fromFen(fen), throwsFormatException, reason: fen);
      }
    });
  });
}
