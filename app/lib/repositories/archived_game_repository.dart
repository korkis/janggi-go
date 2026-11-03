import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:janggi_core/janggi_core.dart';

import '../models/archived_game.dart';

/// Firestore `games_archived` 컬렉션. 끝난 대국의 기보다. 대국 서버만 쓰고 로그인한 사용자가 읽는다.
class ArchivedGameRepository {
  final FirebaseFirestore firestore;

  ArchivedGameRepository({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _games => firestore.collection('games_archived');

  /// [uid]가 둔 대국을 최근에 끝난 것부터 [limit]개 읽는다. [endedBefore]가 있으면 그보다 먼저 끝난 대국부터 읽는다(다음 쪽).
  /// [endedSince]가 있으면 그 뒤에 끝난 대국만 읽는다(오늘 전적).
  Future<List<({String gameId, ArchivedGame game})>> getArchivedGames(
    String uid, {
    required int limit,
    DateTime? endedBefore,
    DateTime? endedSince,
  }) async {
    var query = _games.where('playerUids', arrayContains: uid).orderBy('endedAt', descending: true);
    if (endedBefore != null) {
      query = query.where('endedAt', isLessThan: Timestamp.fromDate(endedBefore));
    }
    if (endedSince != null) {
      query = query.where('endedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(endedSince));
    }
    final snapshot = await query.limit(limit).get();
    return [for (final document in snapshot.docs) (gameId: document.id, game: ArchivedGame.fromJson(document.data()))];
  }

  /// [uid]와 [opponentUid]가 둔 대국 수와 그중 [uid]가 이긴 수(나와의 전적). 세기 쿼리로 문서를 내려받지 않는다.
  Future<({int games, int wins})> getPairRecord(String uid, String opponentUid) async {
    final pairKey = ([uid, opponentUid]..sort()).join('_');
    final pairGames = _games.where('pairKey', isEqualTo: pairKey);
    final counts = await Future.wait([
      pairGames.count().get(),
      for (final side in Side.values)
        pairGames
            .where('players.${side.name}.uid', isEqualTo: uid)
            .where('result.winner', isEqualTo: side.name)
            .count()
            .get(),
    ]);
    // count()만 요청했으므로 값이 있다.
    return (games: counts[0].count!, wins: counts[1].count! + counts[2].count!);
  }
}
