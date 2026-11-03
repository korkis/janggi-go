import '../firebase/firestore_client.dart';
import '../models/user.dart';

/// Firestore `users/{uid}`. 닉네임은 Functions, 급수와 전적은 대국 서버가 쓴다.
class UsersRepository {
  final FirestoreClient firestore;

  const UsersRepository({required this.firestore});

  static const collection = 'users';

  /// [uid]의 공개 프로필. 닉네임을 아직 정하지 않았으면 null.
  Future<User?> getUser(String uid) async {
    final data = await firestore.getDocument('$collection/$uid');
    if (data == null) {
      return null;
    }
    return User.fromJson(data);
  }

  /// [uids]의 공개 프로필을 한 번에 읽는다. 프로필이 없는 사용자는 null.
  Future<Map<String, User?>> getUsers(List<String> uids) async {
    final documents = await firestore.getDocuments([for (final uid in uids) '$collection/$uid']);
    return {
      for (final uid in uids)
        uid: switch (documents['$collection/$uid']) {
          final data? => User.fromJson(data),
          null => null,
        },
    };
  }

  /// [uids]의 공개 프로필을 트랜잭션 안에서 읽는다. 프로필이 없는 사용자는 null.
  Future<Map<String, User?>> getUsersInTransaction(FirestoreTransaction transaction, List<String> uids) async {
    final documents = await transaction.getAll([for (final uid in uids) '$collection/$uid']);
    return {
      for (final uid in uids)
        uid: switch (documents['$collection/$uid']) {
          final data? => User.fromJson(data),
          null => null,
        },
    };
  }

  /// 대국이 끝난 뒤의 전적과, 급수 대국이면 급수를 한 번에 바꾼다. 닉네임 등 Functions가 쓰는 필드는 건드리지 않는다.
  /// [rankLevel]이 null이면 급수는 그대로 둔다.
  void updateRecordInTransaction(
    FirestoreTransaction transaction,
    String uid, {
    required UserStats stats,
    required int? rankLevel,
  }) {
    transaction.update('$collection/$uid', {
      'stats': {'games': stats.games, 'wins': stats.wins, 'losses': stats.losses},
      'rankLevel': ?rankLevel,
    });
  }
}
