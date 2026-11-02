import 'square.dart';

/// 수 하나. 출발 칸과 도착 칸을 붙여 쓰고(예: `b1c3`), 한수쉼은 `pass`로 쓴다.
final class Move {
  static const passText = 'pass';
  static final _pattern = RegExp(r'^([a-i](?:10|[1-9]))([a-i](?:10|[1-9]))$');

  /// 한수쉼.
  static const pass = Move._pass();

  /// 출발 칸. 한수쉼이면 null이다.
  final Square? from;

  /// 도착 칸. 한수쉼이면 null이다.
  final Square? to;

  const Move(Square this.from, Square this.to);

  const Move._pass()
      : from = null,
        to = null;

  factory Move.parse(String text) {
    if (text == passText) {
      return pass;
    }
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('수 표기가 아니다', text);
    }
    return Move(Square.parse(match[1]!), Square.parse(match[2]!));
  }

  bool get isPass => from == null;

  @override
  bool operator ==(Object other) => other is Move && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => isPass ? passText : '$from$to';
}
