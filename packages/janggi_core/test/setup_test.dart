import 'package:janggi_core/janggi_core.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('상차림', () {
    test('양쪽 마상상마', () {
      final position = createInitialPosition(
        cho: Formation.horseElephantElephantHorse,
        han: Formation.horseElephantElephantHorse,
      );
      expect(position.fen, 'rnba1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR w');
    });

    test('초의 상차림은 a 쪽부터, 한의 상차림은 i 쪽부터 센다', () {
      final rank1 = {
        Formation.horseElephantHorseElephant: 'RNBA1ANBR',
        Formation.elephantHorseElephantHorse: 'RBNA1ABNR',
        Formation.horseElephantElephantHorse: 'RNBA1ABNR',
        Formation.elephantHorseHorseElephant: 'RBNA1ANBR',
      };
      final rank10 = {
        Formation.horseElephantHorseElephant: 'rbna1abnr',
        Formation.elephantHorseElephantHorse: 'rnba1anbr',
        Formation.horseElephantElephantHorse: 'rnba1abnr',
        Formation.elephantHorseHorseElephant: 'rbna1anbr',
      };
      for (final cho in Formation.values) {
        for (final han in Formation.values) {
          final fen = createInitialPosition(cho: cho, han: han).fen;
          expect(fen, '${rank10[han]}/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/${rank1[cho]} w');
        }
      }
    });

    test('처음 국면의 점수는 초 72점, 한 73.5점이다', () {
      final position = createInitialPosition(
        cho: Formation.horseElephantHorseElephant,
        han: Formation.elephantHorseHorseElephant,
      );
      expect(position.score(Side.cho), 72);
      expect(position.score(Side.han), 73.5);
    });
  });

  group('접장기', () {
    Position handicap(Set<HandicapPiece> removed) => createInitialPosition(
          cho: Formation.horseElephantHorseElephant,
          han: Formation.horseElephantHorseElephant,
          hanRemoved: removed,
        );

    test('떼는 기물은 한의 기물에서만 빠지고 왼쪽과 오른쪽을 구분한다', () {
      expect(handicap({HandicapPiece.leftChariot}).pieceAt(sq('i10')), isNull);
      expect(handicap({HandicapPiece.leftChariot}).pieceAt(sq('a10')), isNotNull);
      expect(handicap({HandicapPiece.rightChariot}).pieceAt(sq('a10')), isNull);
      expect(handicap({HandicapPiece.leftCannon}).pieceAt(sq('h8')), isNull);
      expect(handicap({HandicapPiece.rightCannon}).pieceAt(sq('b8')), isNull);
      expect(handicap({HandicapPiece.leftChariot}).pieceAt(sq('a1')), isNotNull);
      expect(handicap({HandicapPiece.leftChariot}).pieceAt(sq('i1')), isNotNull);
    });

    test('마와 상은 상차림에 따라 그 절반에 있는 것을 뗀다', () {
      // 한 마상마상은 i10 차, h10 마, g10 상, c10 마, b10 상, a10 차다.
      expect(handicap({HandicapPiece.leftHorse}).pieceAt(sq('h10')), isNull);
      expect(handicap({HandicapPiece.leftElephant}).pieceAt(sq('g10')), isNull);
      expect(handicap({HandicapPiece.rightHorse}).pieceAt(sq('c10')), isNull);
      expect(handicap({HandicapPiece.rightElephant}).pieceAt(sq('b10')), isNull);
      // 한 상마마상은 i10 차, h10 상, g10 마, c10 마, b10 상, a10 차다.
      final crossed = createInitialPosition(
        cho: Formation.horseElephantHorseElephant,
        han: Formation.elephantHorseHorseElephant,
        hanRemoved: {HandicapPiece.leftHorse, HandicapPiece.rightElephant},
      );
      expect(crossed.fen.split('/').first, 'r1na1a1br');
    });

    test('여러 기물을 함께 떼면 점수가 그만큼 낮아진다', () {
      final position = handicap({HandicapPiece.leftChariot, HandicapPiece.leftCannon, HandicapPiece.rightCannon});
      expect(position.fen, 'rbna1abn1/4k4/9/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ANBR w');
      expect(position.score(Side.han), 73.5 - 13 - 7 - 7);
      expect(position.score(Side.cho), 72);
    });
  });
}
