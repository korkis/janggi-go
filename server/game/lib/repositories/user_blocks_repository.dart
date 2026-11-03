import '../firebase/firestore_client.dart';

/// Firestore `users/{uid}/blocks/{blockedUid}`. 차단 목록이다. 앱(본인)이 쓰고 대국 서버는 신청을 전달할 때 읽기만 한다.
class UserBlocksRepository {
  final FirestoreClient firestore;

  const UserBlocksRepository({required this.firestore});

  static const collection = 'blocks';

  /// [uid]가 [blockedUid]를 차단했는지.
  Future<bool> hasBlock(String uid, String blockedUid) async {
    return await firestore.getDocument('users/$uid/$collection/$blockedUid') != null;
  }
}
