/// 진영. 초가 선수, 한이 후수다.
enum Side {
  cho,
  han;

  Side get opponent => this == cho ? han : cho;

  /// 앞쪽 방향의 가로줄 변화량. 초는 위(+1), 한은 아래(-1)로 나아간다.
  int get forward => this == cho ? 1 : -1;
}

/// 기물 종류. [fenLetter]는 Fairy-Stockfish 장기 FEN의 기물 문자(초 기준 대문자)다.
enum PieceType {
  /// 궁. 점수에 넣지 않는다.
  king('K', 0),
  advisor('A', 3),
  elephant('B', 3),
  horse('N', 5),
  chariot('R', 13),
  cannon('C', 7),

  /// 졸(초)·병(한).
  soldier('P', 2);

  final String fenLetter;

  /// 점수 판정에 쓰는 기물 점수.
  final int score;

  const PieceType(this.fenLetter, this.score);
}

/// 판 위의 기물 하나.
final class Piece {
  final Side side;
  final PieceType type;

  const Piece(this.side, this.type);

  /// FEN 기물 문자. 초는 대문자, 한은 소문자다.
  String get fenChar => side == Side.cho ? type.fenLetter : type.fenLetter.toLowerCase();

  /// FEN 기물 문자에 해당하는 기물. 기물 문자가 아니면 null이다.
  static Piece? fromFenChar(String char) {
    for (final type in PieceType.values) {
      if (char == type.fenLetter) {
        return Piece(Side.cho, type);
      }
      if (char == type.fenLetter.toLowerCase()) {
        return Piece(Side.han, type);
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is Piece && other.side == side && other.type == type;

  @override
  int get hashCode => Object.hash(side, type);

  @override
  String toString() => fenChar;
}
