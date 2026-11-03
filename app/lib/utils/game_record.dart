import 'package:janggi_core/janggi_core.dart';

import '../models/archived_game.dart';

// 저장된 기보(`games_archived`)를 복기와 목록에 쓰는 모양으로 바꾼다.

/// [uid]가 둔 진영. 대국자가 아니면 null.
Side? getArchivedPlayerSide(ArchivedGame game, String uid) {
  for (final side in Side.values) {
    if (game.players.get(side).uid == uid) {
      return side;
    }
  }
  return null;
}

/// 처음 국면에서 기보의 수를 다시 둔 대국. 복기 화면과 끝난 판 미리보기에 쓴다.
Game replayArchivedGame(ArchivedGame game) =>
    Game.replay(Position.fromFen(game.initialFen), game.moves.map(Move.parse));

/// 내 기보 목록과 내 정보가 쓰는 내 대국 하나. 기보를 다시 둔 대국과 내 진영을 함께 둔다.
class MyArchivedGame {
  final String gameId;
  final ArchivedGame game;
  final Side mySide;

  /// 처음 국면에서 기보를 다시 둔 대국. 끝난 판 미리보기와 복기에 쓴다.
  final Game record;

  const MyArchivedGame({required this.gameId, required this.game, required this.mySide, required this.record});

  bool get won => game.result.winner == mySide;

  ArchivedPlayer get opponent => game.players.get(mySide.opponent);
}

/// [games] 중 [uid]가 둔 대국을 [MyArchivedGame]으로 바꾼다. 대국자가 아닌 기보는 뺀다.
List<MyArchivedGame> getMyArchivedGames(String uid, List<({String gameId, ArchivedGame game})> games) => [
  for (final item in games)
    if (getArchivedPlayerSide(item.game, uid) case final mySide?)
      MyArchivedGame(gameId: item.gameId, game: item.game, mySide: mySide, record: replayArchivedGame(item.game)),
];
