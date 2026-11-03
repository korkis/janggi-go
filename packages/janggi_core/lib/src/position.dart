import 'move.dart';
import 'movegen.dart';
import 'piece.dart';
import 'square.dart';

part 'game.dart';

/// 국면. 모든 기물의 위치와 다음에 둘 차례다. 불변 객체이며 [play]는 새 국면을 반환한다.
///
/// 반복수처럼 지나온 수가 필요한 판정은 [Position]이 아니라 `Game`이 한다.
final class Position {
  /// 한(후수)에게 더하는 덤.
  static const hanBonus = 1.5;

  /// [Square.index] 순서의 90칸. 빈 칸은 null이다.
  final List<Piece?> board;

  /// 다음에 둘 진영.
  final Side turn;

  Position._(List<Piece?> board, this.turn) : board = List.unmodifiable(board);

  /// [pieces]의 배치와 [turn] 차례로 국면을 만든다.
  factory Position.fromPieces(Map<Square, Piece> pieces, Side turn) {
    final board = List<Piece?>.filled(Square.fileCount * Square.rankCount, null);
    for (final MapEntry(key: square, value: piece) in pieces.entries) {
      board[square.index] = piece;
    }
    return Position._(board, turn);
  }

  /// FEN 방식의 국면 문자열을 읽는다. 예: `rnba1abnr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/RNBA1ABNR w`
  ///
  /// 가로줄 10부터 1까지 `/`로 구분하고, 차례는 초가 `w`, 한이 `b`다.
  factory Position.fromFen(String fen) {
    final fields = fen.split(' ');
    if (fields.length != 2) {
      throw FormatException('국면 문자열은 배치와 차례 두 부분이어야 한다', fen);
    }
    final rows = fields[0].split('/');
    if (rows.length != Square.rankCount) {
      throw FormatException('가로줄이 ${Square.rankCount}개가 아니다', fen);
    }
    final board = List<Piece?>.filled(Square.fileCount * Square.rankCount, null);
    for (var row = 0; row < rows.length; row++) {
      final rank = Square.rankCount - 1 - row;
      var file = 0;
      for (final char in rows[row].split('')) {
        final empty = int.tryParse(char);
        if (empty != null && empty >= 1 && empty <= Square.fileCount) {
          file += empty;
          continue;
        }
        final piece = Piece.fromFenChar(char);
        if (piece == null || file >= Square.fileCount) {
          throw FormatException('가로줄 ${rank + 1}을 읽을 수 없다', fen);
        }
        board[Square(file, rank).index] = piece;
        file++;
      }
      if (file != Square.fileCount) {
        throw FormatException('가로줄 ${rank + 1}의 칸 수가 ${Square.fileCount}가 아니다', fen);
      }
    }
    final turn = switch (fields[1]) {
      'w' => Side.cho,
      'b' => Side.han,
      _ => throw FormatException('차례는 w 또는 b여야 한다', fen),
    };
    return Position._(board, turn);
  }

  /// FEN 방식의 국면 문자열. 같은 국면이면 같은 문자열이므로 반복수 판정의 기준으로도 쓴다.
  late final String fen = _buildFen();

  Piece? pieceAt(Square square) => board[square.index];

  /// 판 위의 모든 기물과 그 칸.
  Map<Square, Piece> get pieces => {
        for (final square in Square.all)
          if (board[square.index] case final piece?) square: piece,
      };

  /// [side]가 장군을 받은 상태인지 판단한다.
  bool isInCheck(Side side) => isKingAttacked(board, side);

  /// [side]에게 장군을 건 상대 기물의 칸. 장군이 아니면 비어 있다. 장군 연출이 장군을 건 기물을 표시하는 데 쓴다.
  List<Square> checkingSquares(Side side) => getKingAttackers(board, side);

  /// 지금 차례가 둘 수 있는 수. 장군이 아니면 한수쉼([Move.pass])도 들어간다.
  ///
  /// 반복수 제한은 지나온 수가 필요하므로 여기서 따지지 않는다. 대국에서는 `Game.legalMoves`를 쓴다.
  List<Move> legalMoves() => [
        ...generateLegalPieceMoves(board, turn),
        if (!isInCheck(turn)) Move.pass,
      ];

  bool isLegal(Move move) => legalMoves().contains(move);

  /// [move]를 둔 새 국면을 반환한다. [isLegal]이 아닌 수면 [ArgumentError]를 던진다.
  Position play(Move move) {
    if (!isLegal(move)) {
      throw ArgumentError.value(move.toString(), 'move', '둘 수 없는 수다 ($fen)');
    }
    return _playUnchecked(move);
  }

  Position _playUnchecked(Move move) => Position._(applyMoveToBoard(board, move), turn.opponent);

  /// [side]의 점수. 남은 기물 점수의 합이고 한은 [hanBonus]를 더한다.
  double score(Side side) {
    var total = 0;
    for (final piece in board) {
      if (piece != null && piece.side == side) {
        total += piece.type.score;
      }
    }
    return side == Side.han ? total + hanBonus : total.toDouble();
  }

  String _buildFen() {
    final rows = <String>[];
    for (var rank = Square.rankCount - 1; rank >= 0; rank--) {
      final row = StringBuffer();
      var empty = 0;
      for (var file = 0; file < Square.fileCount; file++) {
        final piece = board[Square(file, rank).index];
        if (piece == null) {
          empty++;
          continue;
        }
        if (empty > 0) {
          row.write(empty);
          empty = 0;
        }
        row.write(piece.fenChar);
      }
      if (empty > 0) {
        row.write(empty);
      }
      rows.add(row.toString());
    }
    return '${rows.join('/')} ${turn == Side.cho ? 'w' : 'b'}';
  }

  @override
  bool operator ==(Object other) => other is Position && other.fen == fen;

  @override
  int get hashCode => fen.hashCode;

  @override
  String toString() => fen;
}
