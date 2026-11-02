import 'move.dart';
import 'piece.dart';
import 'square.dart';

// 판은 Square.index 순서의 90칸 목록이다. 이 파일은 패키지 밖으로 내보내지 않는다.

const _orthogonals = [(0, 1), (0, -1), (1, 0), (-1, 0)];
const _diagonals = [(1, 1), (1, -1), (-1, 1), (-1, -1)];

/// [square]가 [side]의 궁성 안인지 판단한다.
bool isInPalace(Square square, Side side) {
  if (square.file < 3 || square.file > 5) {
    return false;
  }
  if (side == Side.cho) {
    return square.rank <= 2;
  }
  return square.rank >= 7;
}

Side? _palaceOf(Square square) {
  for (final side in Side.values) {
    if (isInPalace(square, side)) {
      return side;
    }
  }
  return null;
}

bool _isPalaceCenter(Square square) => square.file == 4 && (square.rank == 1 || square.rank == 8);

/// 궁성 대각선을 따라 한 칸 간 칸. 대각선 선이 없으면 null이다.
///
/// 궁성 대각선은 귀와 가운데를 잇는 선이므로 두 칸 중 하나가 같은 궁성의 가운데여야 한다.
Square? palaceDiagonalStep(Square square, int fileDelta, int rankDelta) {
  final target = square.offset(fileDelta, rankDelta);
  if (target == null) {
    return null;
  }
  final palace = _palaceOf(square);
  if (palace == null || _palaceOf(target) != palace) {
    return null;
  }
  if (!_isPalaceCenter(square) && !_isPalaceCenter(target)) {
    return null;
  }
  return target;
}

/// [side]의 기물이 둘 수 있는 수를 자기 궁 장군 여부를 따지지 않고 모두 만든다.
List<Move> generatePseudoMoves(List<Piece?> board, Side side) {
  final moves = <Move>[];
  for (final square in Square.all) {
    final piece = board[square.index];
    if (piece == null || piece.side != side) {
      continue;
    }
    for (final target in _targets(board, square, piece)) {
      moves.add(Move(square, target));
    }
  }
  return moves;
}

Iterable<Square> _targets(List<Piece?> board, Square from, Piece piece) {
  switch (piece.type) {
    case PieceType.king:
    case PieceType.advisor:
      return _palaceStepTargets(board, from, piece.side);
    case PieceType.chariot:
      return _chariotTargets(board, from, piece.side);
    case PieceType.cannon:
      return _cannonTargets(board, from, piece.side);
    case PieceType.horse:
      return _horseTargets(board, from, piece.side);
    case PieceType.elephant:
      return _elephantTargets(board, from, piece.side);
    case PieceType.soldier:
      return _soldierTargets(board, from, piece.side);
  }
}

bool _canLand(List<Piece?> board, Square target, Side side) => board[target.index]?.side != side;

Iterable<Square> _palaceStepTargets(List<Piece?> board, Square from, Side side) sync* {
  for (final (df, dr) in _orthogonals) {
    final target = from.offset(df, dr);
    if (target != null && isInPalace(target, side) && _canLand(board, target, side)) {
      yield target;
    }
  }
  for (final (df, dr) in _diagonals) {
    final target = palaceDiagonalStep(from, df, dr);
    if (target != null && isInPalace(target, side) && _canLand(board, target, side)) {
      yield target;
    }
  }
}

Iterable<Square> _chariotTargets(List<Piece?> board, Square from, Side side) sync* {
  for (final (df, dr) in _orthogonals) {
    var target = from.offset(df, dr);
    while (target != null) {
      final occupant = board[target.index];
      if (occupant == null) {
        yield target;
      } else {
        if (occupant.side != side) {
          yield target;
        }
        break;
      }
      target = target.offset(df, dr);
    }
  }
  for (final (df, dr) in _diagonals) {
    var target = palaceDiagonalStep(from, df, dr);
    while (target != null) {
      final occupant = board[target.index];
      if (occupant == null) {
        yield target;
      } else {
        if (occupant.side != side) {
          yield target;
        }
        break;
      }
      target = palaceDiagonalStep(target, df, dr);
    }
  }
}

/// 포는 포가 아닌 기물 하나를 정확히 넘어 움직이고, 포는 잡지 못한다.
Iterable<Square> _cannonTargets(List<Piece?> board, Square from, Side side) sync* {
  for (final (df, dr) in _orthogonals) {
    var screen = from.offset(df, dr);
    while (screen != null && board[screen.index] == null) {
      screen = screen.offset(df, dr);
    }
    if (screen == null || board[screen.index]!.type == PieceType.cannon) {
      continue;
    }
    var target = screen.offset(df, dr);
    while (target != null) {
      final occupant = board[target.index];
      if (occupant == null) {
        yield target;
      } else {
        if (occupant.side != side && occupant.type != PieceType.cannon) {
          yield target;
        }
        break;
      }
      target = target.offset(df, dr);
    }
  }
  for (final (df, dr) in _diagonals) {
    final screen = palaceDiagonalStep(from, df, dr);
    if (screen == null) {
      continue;
    }
    final screenPiece = board[screen.index];
    if (screenPiece == null || screenPiece.type == PieceType.cannon) {
      continue;
    }
    final target = palaceDiagonalStep(screen, df, dr);
    if (target == null) {
      continue;
    }
    final occupant = board[target.index];
    if (occupant == null || (occupant.side != side && occupant.type != PieceType.cannon)) {
      yield target;
    }
  }
}

Iterable<Square> _horseTargets(List<Piece?> board, Square from, Side side) sync* {
  for (final (df, dr) in _orthogonals) {
    final leg = from.offset(df, dr);
    if (leg == null || board[leg.index] != null) {
      continue;
    }
    for (final sideStep in [-1, 1]) {
      // 직선 방향에 수직인 쪽으로 한 칸 더 벌어지는 대각선이다.
      final target = leg.offset(df + (dr != 0 ? sideStep : 0), dr + (df != 0 ? sideStep : 0));
      if (target != null && _canLand(board, target, side)) {
        yield target;
      }
    }
  }
}

Iterable<Square> _elephantTargets(List<Piece?> board, Square from, Side side) sync* {
  for (final (df, dr) in _orthogonals) {
    final leg = from.offset(df, dr);
    if (leg == null || board[leg.index] != null) {
      continue;
    }
    for (final sideStep in [-1, 1]) {
      final diagFile = df + (dr != 0 ? sideStep : 0);
      final diagRank = dr + (df != 0 ? sideStep : 0);
      final middle = leg.offset(diagFile, diagRank);
      if (middle == null || board[middle.index] != null) {
        continue;
      }
      final target = middle.offset(diagFile, diagRank);
      if (target != null && _canLand(board, target, side)) {
        yield target;
      }
    }
  }
}

Iterable<Square> _soldierTargets(List<Piece?> board, Square from, Side side) sync* {
  for (final (df, dr) in [(0, side.forward), (1, 0), (-1, 0)]) {
    final target = from.offset(df, dr);
    if (target != null && _canLand(board, target, side)) {
      yield target;
    }
  }
  for (final df in [-1, 1]) {
    final target = palaceDiagonalStep(from, df, side.forward);
    if (target != null && isInPalace(target, side.opponent) && _canLand(board, target, side)) {
      yield target;
    }
  }
}

/// [move]를 둔 새 판을 반환한다. 한수쉼이면 같은 배치의 복사본이다.
List<Piece?> applyMoveToBoard(List<Piece?> board, Move move) {
  final next = List<Piece?>.of(board);
  if (!move.isPass) {
    next[move.to!.index] = next[move.from!.index];
    next[move.from!.index] = null;
  }
  return next;
}

/// [side]의 궁이 상대 기물에게 잡힐 수 있는 상태(장군)인지 판단한다. 궁이 없으면 false다.
bool isKingAttacked(List<Piece?> board, Side side) {
  final kingIndex = board.indexOf(Piece(side, PieceType.king));
  if (kingIndex < 0) {
    return false;
  }
  for (final move in generatePseudoMoves(board, side.opponent)) {
    if (move.to!.index == kingIndex) {
      return true;
    }
  }
  return false;
}

/// [side]가 둘 수 있는 기물 수 중 자기 궁이 장군으로 남지 않는 수.
List<Move> generateLegalPieceMoves(List<Piece?> board, Side side) => [
      for (final move in generatePseudoMoves(board, side))
        if (!isKingAttacked(applyMoveToBoard(board, move), side)) move,
    ];

/// [by]가 차례와 상관없이 지금 판에서 합법적으로 잡을 수 있는 상대 기물(궁 제외)의 칸.
Set<Square> capturableSquares(List<Piece?> board, Side by) => {
      for (final move in generateLegalPieceMoves(board, by))
        if (board[move.to!.index] case final target? when target.type != PieceType.king) move.to!,
    };
