import '../firebase/firestore_client.dart';
import '../models/user.dart';

/// Firestore `users/{uid}`.
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
}
