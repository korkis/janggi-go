import '../firebase/firestore_client.dart';
import '../models/challenge_limit.dart';

/// Firestore `challenge_limits/{fromUid}_{toUid}`. 같은 상대에게 신청을 남발하지 못하게 하는 기록이다. 서버 전용이다.
class ChallengeLimitsRepository {
  final FirestoreClient firestore;

  const ChallengeLimitsRepository({required this.firestore});

  static const collection = 'challenge_limits';

  /// [fromUid]가 [toUid]에게 보낸 신청의 기록. 아직 없으면 null.
  Future<ChallengeLimit?> getLimit(String fromUid, String toUid) async {
    final data = await firestore.getDocument(_path(fromUid, toUid));
    return data == null ? null : ChallengeLimit.fromJson(data);
  }

  Future<ChallengeLimit?> getLimitInTransaction(FirestoreTransaction transaction, String fromUid, String toUid) async {
    final data = await transaction.get(_path(fromUid, toUid));
    return data == null ? null : ChallengeLimit.fromJson(data);
  }

  void setLimitInTransaction(FirestoreTransaction transaction, String fromUid, String toUid, ChallengeLimit limit) {
    transaction.set(_path(fromUid, toUid), limit.toJson());
  }

  static String _path(String fromUid, String toUid) => '$collection/${fromUid}_$toUid';
}
