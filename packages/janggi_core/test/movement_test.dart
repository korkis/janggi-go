import 'package:janggi_core/janggi_core.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

/// 칸 표기와 FEN 기물 문자로 국면을 만든다.
Position place(Map<String, String> pieces, {Side turn = Side.cho}) => Position.fromPieces(
      {for (final MapEntry(key: square, value: char) in pieces.entries) sq(square): Piece.fromFenChar(char)!},
      turn,
    );

void main() {
  test('처음 국면(양쪽 마상상마)의 합법수는 한수쉼을 포함해 32개다', () {
    final position = createInitialPosition(
      cho: Formation.horseElephantElephantHorse,
      han: Formation.horseElephantElephantHorse,
    );
    final moves = position.legalMoves();
    expect(moves.length, 32);
    expect(moves, contains(Move.pass));
    expect(targetsFrom(position, 'b3'), isEmpty);
    expect(targetsFrom(position, 'c1'), isEmpty);
    expect(targetsFrom(position, 'e2'), ['d2', 'd3', 'e1', 'e3', 'f2', 'f3']);
  });

  group('궁과 사', () {
    test('궁성 가운데에서는 대각선을 포함해 여덟 방향으로 한 칸 움직인다', () {
      final position = place({'e2': 'K', 'd10': 'k'});
      expect(targetsFrom(position, 'e2'), ['d1', 'd2', 'd3', 'e1', 'e3', 'f1', 'f2', 'f3']);
    });

    test('대각선이 없는 자리에서는 선을 따라서만 움직인다', () {
      expect(targetsFrom(place({'d2': 'K', 'f10': 'k'}), 'd2'), ['d1', 'd3', 'e2']);
      expect(targetsFrom(place({'e1': 'K', 'f10': 'k'}), 'e1'), ['d1', 'e2', 'f1']);
    });

    test('궁성 귀에서는 가운데로 가는 대각선만 있다', () {
      expect(targetsFrom(place({'d1': 'K', 'f10': 'k'}), 'd1'), ['d2', 'e1', 'e2']);
    });

    test('사도 궁성 안에서 궁과 같이 움직인다', () {
      final position = place({'e9': 'a', 'f10': 'k', 'd1': 'K'}, turn: Side.han);
      expect(targetsFrom(position, 'e9'), ['d10', 'd8', 'd9', 'e10', 'e8', 'f8', 'f9']);
      expect(targetsFrom(place({'f3': 'A', 'd1': 'K', 'f10': 'k'}), 'f3'), ['e2', 'e3', 'f2']);
    });
  });

  group('차', () {
    test('가로·세로로 막히지 않은 만큼 움직이고 상대 기물을 잡는다', () {
      final position = place({'a1': 'R', 'a5': 'p', 'c1': 'N', 'f2': 'K', 'f9': 'k'});
      expect(targetsFrom(position, 'a1'), ['a2', 'a3', 'a4', 'a5', 'b1']);
    });

    test('궁성 안에서는 대각선을 따라 움직인다', () {
      final position = place({'d1': 'R', 'f2': 'K', 'f9': 'k'});
      final targets = targetsFrom(position, 'd1');
      expect(targets, containsAll(['e2', 'f3']));
      expect(targets.length, 19);
      expect(targetsFrom(place({'d8': 'R', 'f2': 'K', 'd10': 'k'}), 'd8'), containsAll(['e9', 'f10']));
    });

    test('궁성 대각선 위에 기물이 있으면 거기서 멈춘다', () {
      expect(targetsFrom(place({'d1': 'R', 'e2': 'A', 'f1': 'K', 'f9': 'k'}), 'd1'), isNot(contains('e2')));
      expect(targetsFrom(place({'d1': 'R', 'e2': 'a', 'f1': 'K', 'f9': 'k'}), 'd1'), containsAll(['e2']));
      expect(targetsFrom(place({'d1': 'R', 'e2': 'a', 'f1': 'K', 'f9': 'k'}), 'd1'), isNot(contains('f3')));
    });

    test('대각선 선이 없는 자리에서는 대각선으로 움직이지 않는다', () {
      final targets = targetsFrom(place({'d2': 'R', 'f1': 'K', 'f9': 'k'}), 'd2');
      expect(targets, isNot(contains('e1')));
      expect(targets, isNot(contains('e3')));
    });
  });

  group('포', () {
    test('기물 하나를 넘어 움직이고 그 너머 상대 기물을 잡는다', () {
      final position = place({'a1': 'C', 'a4': 'p', 'a8': 'r', 'f2': 'K', 'd9': 'k'});
      expect(targetsFrom(position, 'a1'), ['a5', 'a6', 'a7', 'a8']);
    });

    test('넘을 기물이 없으면 움직일 수 없다', () {
      expect(targetsFrom(place({'a1': 'C', 'f2': 'K', 'd9': 'k'}), 'a1'), isEmpty);
    });

    test('포는 포를 넘을 수 없다', () {
      expect(targetsFrom(place({'a1': 'C', 'a4': 'C', 'f2': 'K', 'd9': 'k'}), 'a1'), isEmpty);
      expect(targetsFrom(place({'a1': 'C', 'a4': 'c', 'f2': 'K', 'd9': 'k'}), 'a1'), isEmpty);
    });

    test('포는 포를 잡을 수 없다', () {
      final position = place({'a1': 'C', 'a4': 'p', 'a8': 'c', 'f2': 'K', 'd9': 'k'});
      expect(targetsFrom(position, 'a1'), ['a5', 'a6', 'a7']);
    });

    test('궁성 안에서는 가운데 기물을 넘어 대각선으로 움직인다', () {
      expect(targetsFrom(place({'d1': 'C', 'e2': 'A', 'f1': 'K', 'f9': 'k'}), 'd1'), contains('f3'));
      expect(targetsFrom(place({'d1': 'C', 'e2': 'A', 'f3': 'r', 'f1': 'K', 'd9': 'k'}), 'd1'), contains('f3'));
      expect(targetsFrom(place({'d1': 'C', 'f1': 'K', 'f9': 'k'}), 'd1'), isNot(contains('f3')));
      expect(targetsFrom(place({'d1': 'C', 'f1': 'K', 'f9': 'k'}), 'd1'), isNot(contains('e2')));
      expect(targetsFrom(place({'d1': 'C', 'e2': 'C', 'f1': 'K', 'f9': 'k'}), 'd1'), isNot(contains('f3')));
      expect(targetsFrom(place({'d1': 'C', 'e2': 'A', 'f3': 'c', 'f1': 'K', 'd9': 'k'}), 'd1'), isNot(contains('f3')));
      expect(targetsFrom(place({'d8': 'C', 'e9': 'p', 'f2': 'K', 'f9': 'k'}), 'd8'), contains('f10'));
    });
  });

  group('마', () {
    test('한 칸 직진 뒤 바깥쪽 대각선으로 한 칸 간다', () {
      final position = place({'e5': 'N', 'd1': 'K', 'f10': 'k'});
      expect(targetsFrom(position, 'e5'), ['c4', 'c6', 'd3', 'd7', 'f3', 'f7', 'g4', 'g6']);
    });

    test('처음 한 칸 자리에 기물이 있으면 그쪽으로 갈 수 없다(멱)', () {
      final position = place({'e5': 'N', 'e6': 'p', 'd5': 'P', 'd1': 'K', 'f10': 'k'});
      expect(targetsFrom(position, 'e5'), ['d3', 'f3', 'g4', 'g6']);
    });
  });

  group('상', () {
    test('한 칸 직진 뒤 같은 방향 대각선으로 두 칸 간다', () {
      final position = place({'e5': 'B', 'd1': 'K', 'f10': 'k'});
      expect(targetsFrom(position, 'e5'), ['b3', 'b7', 'c2', 'c8', 'g2', 'g8', 'h3', 'h7']);
    });

    test('지나는 자리에 기물이 있으면 갈 수 없다', () {
      // e6은 c8·g8로 가는 첫 자리, g4는 h3으로 가는 대각선 중간 자리다.
      final position = place({'e5': 'B', 'e6': 'p', 'g4': 'P', 'd1': 'K', 'f10': 'k'});
      expect(targetsFrom(position, 'e5'), ['b3', 'b7', 'c2', 'g2', 'h7']);
    });
  });

  group('졸·병', () {
    test('앞이나 옆으로 한 칸 움직이고 뒤로는 못 간다', () {
      expect(targetsFrom(place({'e5': 'P', 'd1': 'K', 'f10': 'k'}), 'e5'), ['d5', 'e6', 'f5']);
      expect(targetsFrom(place({'e5': 'p', 'd1': 'K', 'f10': 'k'}, turn: Side.han), 'e5'), ['d5', 'e4', 'f5']);
      expect(targetsFrom(place({'a10': 'P', 'd1': 'K', 'f10': 'k'}), 'a10'), ['b10']);
    });

    test('상대 궁성 안에서는 궁성 대각선을 따라 앞쪽 대각선으로도 움직인다', () {
      expect(targetsFrom(place({'d8': 'P', 'd1': 'K', 'f10': 'k'}), 'd8'), ['c8', 'd9', 'e8', 'e9']);
      expect(targetsFrom(place({'e9': 'P', 'd1': 'K', 'd8': 'k'}), 'e9'), ['d10', 'd9', 'e10', 'f10', 'f9']);
      expect(targetsFrom(place({'e8': 'P', 'd1': 'K', 'f10': 'k'}), 'e8'), ['d8', 'e9', 'f8']);
      expect(targetsFrom(place({'f3': 'p', 'd1': 'K', 'f10': 'k'}, turn: Side.han), 'f3'), ['e2', 'e3', 'f2', 'g3']);
    });

    test('자기 궁성에서는 대각선으로 움직이지 않는다', () {
      expect(targetsFrom(place({'d1': 'P', 'f2': 'K', 'f10': 'k'}), 'd1'), ['c1', 'd2', 'e1']);
    });
  });

  group('장군', () {
    test('상대 기물이 궁을 잡을 수 있으면 장군이다', () {
      expect(place({'e2': 'K', 'e8': 'r', 'd10': 'k'}).isInCheck(Side.cho), isTrue);
      expect(place({'e2': 'K', 'e5': 'P', 'e8': 'r', 'd10': 'k'}).isInCheck(Side.cho), isFalse);
      expect(place({'e2': 'K', 'e5': 'P', 'e8': 'c', 'd10': 'k'}).isInCheck(Side.cho), isTrue);
      expect(place({'e2': 'K', 'd4': 'n', 'd10': 'k'}).isInCheck(Side.cho), isTrue);
      expect(place({'e2': 'K', 'd3': 'p', 'd10': 'k'}).isInCheck(Side.cho), isTrue);
    });

    test('장군을 건 기물과 궁의 칸을 알려 준다', () {
      final position = place({'e2': 'K', 'e8': 'r', 'd4': 'n', 'd10': 'k'});
      expect(position.checkingSquares(Side.cho).map((square) => square.toString()).toList()..sort(), ['d4', 'e8']);
      expect(position.kingSquare(Side.cho).toString(), 'e2');
      expect(place({'e2': 'K', 'e5': 'P', 'e8': 'r', 'd10': 'k'}).checkingSquares(Side.cho), isEmpty);
      expect(place({'e2': 'K', 'd10': 'k'}).kingSquare(Side.han).toString(), 'd10');
    });

    test('자기 궁이 장군으로 남는 수는 둘 수 없다', () {
      // e5 졸은 e8 차를 막고 있어서 옆으로 움직일 수 없다.
      final position = place({'e2': 'K', 'e5': 'P', 'e8': 'r', 'd10': 'k'});
      expect(targetsFrom(position, 'e5'), ['e6']);
      expect(() => position.play(mv('e5d5')), throwsArgumentError);
    });

    test('장군을 받으면 장군을 벗어나는 수만 둘 수 있고 한수쉼은 할 수 없다', () {
      final position = place({'e2': 'K', 'a5': 'R', 'e8': 'r', 'd10': 'k'});
      expect(position.legalMoves(), isNot(contains(Move.pass)));
      expect(position.legalMoves().map((move) => move.toString()).toSet(),
          {'d1', 'd2', 'd3', 'f1', 'f2', 'f3'}.map((to) => 'e2$to').toSet()..add('a5e5'));
    });

    test('빅장을 만드는 수도 둘 수 있다', () {
      final position = place({'d1': 'K', 'e10': 'k'});
      expect(position.isLegal(mv('d1e1')), isTrue);
      final game = Game.start(position).play(mv('d1e1'));
      expect(game.isOver, isFalse);
    });
  });

  group('불변 국면', () {
    test('수를 두면 새 국면을 반환하고 원래 국면은 그대로다', () {
      final position = createInitialPosition(
        cho: Formation.horseElephantHorseElephant,
        han: Formation.horseElephantHorseElephant,
      );
      final before = position.fen;
      final next = position.play(mv('a4a5'));
      expect(position.fen, before);
      expect(next.fen, isNot(before));
      expect(next.turn, Side.han);
      expect(next.pieceAt(sq('a5')), const Piece(Side.cho, PieceType.soldier));
      expect(() => position.board[0] = null, throwsUnsupportedError);
    });

    test('한수쉼은 배치를 그대로 두고 차례만 넘긴다', () {
      final position = place({'e2': 'K', 'd10': 'k'});
      final next = position.play(Move.pass);
      expect(next.turn, Side.han);
      expect(next.pieces, position.pieces);
    });
  });
}
