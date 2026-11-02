import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_private.dart';

/// Firestore `users_private` 컬렉션. 본인만 읽는다. 급수 진행은 대국 서버가 쓴다.
class UserPrivateRepository {
  final FirebaseFirestore firestore;

  UserPrivateRepository({required this.firestore});

  /// 본인의 비공개 정보를 듣는다. 프로필을 만들기 전이면 null을 보낸다.
  Stream<UserPrivate?> watchUserPrivate(String uid) =>
      firestore.collection('users_private').doc(uid).snapshots().map(_decode);

  static UserPrivate? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return data == null ? null : UserPrivate.fromJson(data);
  }
}
