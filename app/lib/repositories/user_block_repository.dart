import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `users/{uid}/blocks` 하위 컬렉션. 차단 목록이다. 본인만 읽고, 만들고, 지운다.
class UserBlockRepository {
  final FirebaseFirestore firestore;

  UserBlockRepository({required this.firestore});

  CollectionReference<Map<String, dynamic>> _blocks(String uid) =>
      firestore.collection('users').doc(uid).collection('blocks');

  /// [uid]가 차단한 사람들의 uid를 듣는다.
  Stream<Set<String>> watchBlockedUids(String uid) => _blocks(uid).snapshots().map(_decodeUids);

  /// [uid]가 [blockedUid]를 차단한다. 보안 규칙이 차단 시각을 서버 시각으로만 받는다.
  Future<void> createBlock(String uid, String blockedUid) async {
    await _blocks(uid).doc(blockedUid).set({'createdAt': FieldValue.serverTimestamp()});
  }

  static Set<String> _decodeUids(QuerySnapshot<Map<String, dynamic>> snapshot) => {
    for (final document in snapshot.docs) document.id,
  };
}
