import 'package:janggi_core/janggi_core.dart';

Square sq(String text) => Square.parse(text);

Move mv(String text) => Move.parse(text);

/// [from] 칸 기물이 갈 수 있는 도착 칸 표기를 정렬해 반환한다.
List<String> targetsFrom(Position position, String from) {
  final targets = [
    for (final move in position.legalMoves())
      if (move.from == sq(from)) move.to.toString(),
  ];
  targets.sort();
  return targets;
}

/// [fen] 국면에서 공백으로 구분한 [moves]를 차례로 둔 대국.
Game replay(String fen, String moves) =>
    Game.replay(Position.fromFen(fen), moves.split(' ').where((text) => text.isNotEmpty).map(Move.parse));
