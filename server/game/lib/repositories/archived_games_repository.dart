import '../firebase/firestore_client.dart';
import '../models/archived_game.dart';

/// Firestore `games_archived/{gameId}`. 끝난 대국의 기보와 결과다.
class ArchivedGamesRepository {
  final FirestoreClient firestore;

  const ArchivedGamesRepository({required this.firestore});

  static const collection = 'games_archived';

  Future<bool> hasArchivedGame(String gameId) async => await firestore.getDocument('$collection/$gameId') != null;

  Future<bool> hasArchivedGameInTransaction(FirestoreTransaction transaction, String gameId) async {
    return await transaction.get('$collection/$gameId') != null;
  }

  /// 기보를 만든다. 이미 있으면 커밋이 실패한다.
  void createArchivedGameInTransaction(FirestoreTransaction transaction, String gameId, ArchivedGame game) {
    transaction.create('$collection/$gameId', game.toJson());
  }
}
