import 'package:janggi_core/janggi_core.dart';

import '../firebase/firestore_client.dart';
import '../models/player_state.dart';

/// Firestore `player_states/{uid}`. 대국 서버만 쓴다.
class PlayerStatesRepository {
  final FirestoreClient firestore;

  const PlayerStatesRepository({required this.firestore});

  static const collection = 'player_states';

  /// 아직 아무것도 하지 않은 사용자는 문서가 없으므로 null.
  Future<PlayerState?> getPlayerState(String uid) async {
    final data = await firestore.getDocument('$collection/$uid');
    return data == null ? null : PlayerState.fromJson(data);
  }

  /// [uids]의 상태를 한 번에 읽는다. 문서가 없는 사용자는 null.
  Future<Map<String, PlayerState?>> getPlayerStates(List<String> uids) async {
    final documents = await firestore.getDocuments([for (final uid in uids) '$collection/$uid']);
    return _decodeAll(uids, documents);
  }

  Future<Map<String, PlayerState?>> getPlayerStatesInTransaction(
    FirestoreTransaction transaction,
    List<String> uids,
  ) async {
    final documents = await transaction.getAll([for (final uid in uids) '$collection/$uid']);
    return _decodeAll(uids, documents);
  }

  /// 트랜잭션에서 읽은 문서를 [state]로 바꾼다. 문서가 없었으면 만든다.
  void setPlayerStateInTransaction(FirestoreTransaction transaction, String uid, PlayerState state) {
    transaction.set('$collection/$uid', state.toJson());
  }

  /// 상차림 화면에서 골라 둔 것을 쓴다. 대국에 묶인 사용자만 부르므로 문서가 있어야 한다.
  Future<void> updateSetupDraft(
    String uid, {
    required String gameId,
    required Formation formation,
    required DateTime now,
  }) {
    final draft = SetupDraft(gameId: gameId, formation: formation);
    return firestore.commit([
      UpdateWrite('$collection/$uid', {'setupDraft': draft.toJson(), 'updatedAt': now}),
    ]);
  }

  static Map<String, PlayerState?> _decodeAll(List<String> uids, Map<String, Map<String, Object?>?> documents) {
    return {
      for (final uid in uids)
        uid: switch (documents['$collection/$uid']) {
          final data? => PlayerState.fromJson(data),
          null => null,
        },
    };
  }
}
