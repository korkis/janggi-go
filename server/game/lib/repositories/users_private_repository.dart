import '../firebase/firestore_client.dart';
import '../models/user_private.dart';

/// Firestore `users_private/{uid}`. Functions가 만들고 대국 서버는 급수 진행만 쓴다.
class UsersPrivateRepository {
  final FirestoreClient firestore;

  const UsersPrivateRepository({required this.firestore});

  static const collection = 'users_private';

  /// [uid]의 비공개 정보. 프로필을 만들기 전이면 null.
  Future<UserPrivate?> getUserPrivate(String uid) async {
    final data = await firestore.getDocument('$collection/$uid');
    return data == null ? null : UserPrivate.fromJson(data);
  }

  /// [uids] 각각의 문서가 있는지.
  Future<Map<String, bool>> hasUsersPrivateInTransaction(FirestoreTransaction transaction, List<String> uids) async {
    final documents = await transaction.getAll([for (final uid in uids) '$collection/$uid']);
    return {for (final uid in uids) uid: documents['$collection/$uid'] != null};
  }

  /// 급수 진행 막대와 어림 승수를 쓴다. 문서가 없으면 커밋이 실패한다.
  void updateRankProgressInTransaction(
    FirestoreTransaction transaction,
    String uid, {
    required double rankProgress,
    required int? winsToNextRank,
  }) {
    transaction.update('$collection/$uid', {'rankProgress': rankProgress, 'winsToNextRank': winsToNextRank});
  }
}
