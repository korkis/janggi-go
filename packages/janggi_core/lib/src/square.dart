/// 판의 교차점 하나. 초 진영이 아래에 오도록 판을 놓고 본 좌표다.
///
/// 문자열 표기는 세로줄 `a`~`i`와 가로줄 `1`~`10`을 붙여 쓴다. 예: `e2`, `a10`
final class Square {
  static const fileCount = 9;
  static const rankCount = 10;
  static const _fileLetters = 'abcdefghi';
  static final _pattern = RegExp(r'^([a-i])(10|[1-9])$');

  /// 판의 모든 칸. [index] 순서다.
  static final List<Square> all = List.unmodifiable([
    for (var rank = 0; rank < rankCount; rank++)
      for (var file = 0; file < fileCount; file++) Square._(file, rank),
  ]);

  /// 세로줄 번호. 0이 `a`, 8이 `i`다.
  final int file;

  /// 가로줄 번호. 0이 `1`, 9가 `10`이다.
  final int rank;

  const Square._(this.file, this.rank);

  factory Square(int file, int rank) {
    final square = tryAt(file, rank);
    if (square == null) {
      throw RangeError('판 밖의 좌표다: file=$file, rank=$rank');
    }
    return square;
  }

  factory Square.parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('칸 표기가 아니다', text);
    }
    return Square(_fileLetters.indexOf(match[1]!), int.parse(match[2]!) - 1);
  }

  /// 판 안이면 그 칸, 판 밖이면 null을 반환한다.
  static Square? tryAt(int file, int rank) {
    if (file < 0 || file >= fileCount || rank < 0 || rank >= rankCount) {
      return null;
    }
    return all[rank * fileCount + file];
  }

  /// [Position.board]에서 이 칸의 위치.
  int get index => rank * fileCount + file;

  /// 세로줄로 [fileDelta], 가로줄로 [rankDelta]만큼 옮긴 칸. 판 밖이면 null이다.
  Square? offset(int fileDelta, int rankDelta) => tryAt(file + fileDelta, rank + rankDelta);

  @override
  bool operator ==(Object other) => other is Square && other.file == file && other.rank == rank;

  @override
  int get hashCode => index;

  @override
  String toString() => '${_fileLetters[file]}${rank + 1}';
}
