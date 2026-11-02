import 'piece.dart';
import 'position.dart';
import 'square.dart';

/// 상차림. 마와 상의 배치를 각 진영이 자기 쪽에서 판을 볼 때의 왼쪽부터 오른쪽 순서로 나타낸다.
///
/// 한은 판의 위쪽에서 보므로 한의 왼쪽은 `i` 세로줄 쪽이다.
enum Formation {
  /// 마상마상
  horseElephantHorseElephant([PieceType.horse, PieceType.elephant, PieceType.horse, PieceType.elephant]),

  /// 상마상마
  elephantHorseElephantHorse([PieceType.elephant, PieceType.horse, PieceType.elephant, PieceType.horse]),

  /// 마상상마
  horseElephantElephantHorse([PieceType.horse, PieceType.elephant, PieceType.elephant, PieceType.horse]),

  /// 상마마상
  elephantHorseHorseElephant([PieceType.elephant, PieceType.horse, PieceType.horse, PieceType.elephant]);

  /// 왼쪽부터 마·상 네 자리의 기물.
  final List<PieceType> pieces;

  const Formation(this.pieces);
}

/// 왼쪽·오른쪽. 기물을 가진 진영이 자기 쪽에서 판을 볼 때 기준이다.
enum BoardSide { left, right }

/// 접장기에서 뗄 수 있는 기물. 같은 기물 두 개를 왼쪽과 오른쪽으로 구분한다.
///
/// 마와 상은 상차림에 따라 자리가 달라지지만, 어느 상차림이든 왼쪽 절반과 오른쪽 절반에 마와 상이
/// 하나씩 있으므로 그 절반에 있는 것을 가리킨다.
enum HandicapPiece {
  leftChariot(PieceType.chariot, BoardSide.left),
  rightChariot(PieceType.chariot, BoardSide.right),
  leftCannon(PieceType.cannon, BoardSide.left),
  rightCannon(PieceType.cannon, BoardSide.right),
  leftHorse(PieceType.horse, BoardSide.left),
  rightHorse(PieceType.horse, BoardSide.right),
  leftElephant(PieceType.elephant, BoardSide.left),
  rightElephant(PieceType.elephant, BoardSide.right);

  final PieceType type;
  final BoardSide side;

  const HandicapPiece(this.type, this.side);
}

/// 상차림과 접장기를 반영한 처음 국면을 만든다. 차례는 초다.
///
/// 접장기에서 기물을 떼는 쪽은 항상 한이므로 [hanRemoved]는 한의 기물에만 적용한다.
Position createInitialPosition({
  required Formation cho,
  required Formation han,
  Set<HandicapPiece> hanRemoved = const {},
}) {
  final pieces = <Square, Piece>{};
  _placeSide(pieces, Side.cho, cho, const {});
  _placeSide(pieces, Side.han, han, hanRemoved);
  return Position.fromPieces(pieces, Side.cho);
}

/// [side]의 기물을 놓는다. 안쪽의 slot은 그 진영이 자기 쪽에서 볼 때 왼쪽부터 센 세로줄 순서(0~8)다.
void _placeSide(Map<Square, Piece> pieces, Side side, Formation formation, Set<HandicapPiece> removed) {
  Square at(int slot, int ownRank) {
    final file = side == Side.cho ? slot : Square.fileCount - 1 - slot;
    final rank = side == Side.cho ? ownRank : Square.rankCount - 1 - ownRank;
    return Square(file, rank);
  }

  void put(int slot, int ownRank, PieceType type, BoardSide? handicapSide) {
    if (handicapSide != null && removed.any((piece) => piece.type == type && piece.side == handicapSide)) {
      return;
    }
    pieces[at(slot, ownRank)] = Piece(side, type);
  }

  BoardSide halfOf(int slot) => slot < 4 ? BoardSide.left : BoardSide.right;

  put(0, 0, PieceType.chariot, BoardSide.left);
  put(8, 0, PieceType.chariot, BoardSide.right);
  const formationSlots = [1, 2, 6, 7];
  for (var i = 0; i < formationSlots.length; i++) {
    final slot = formationSlots[i];
    put(slot, 0, formation.pieces[i], halfOf(slot));
  }
  put(3, 0, PieceType.advisor, null);
  put(5, 0, PieceType.advisor, null);
  put(4, 1, PieceType.king, null);
  put(1, 2, PieceType.cannon, BoardSide.left);
  put(7, 2, PieceType.cannon, BoardSide.right);
  for (final slot in [0, 2, 4, 6, 8]) {
    put(slot, 3, PieceType.soldier, null);
  }
}
