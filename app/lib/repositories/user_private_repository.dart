import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_private.dart';

/// Firestore `users_private` 컬렉션. 본인만 읽는다. 급수 진행은 대국 서버가 쓴다.
class UserPrivateRepository {
  final FirebaseFirestore firestore;

  UserPrivateRepository({required this.firestore});

  /// 본인의 비공개 정보를 듣는다. 프로필을 만들기 전이면 null을 보낸다.
  Stream<UserPrivate?> watchUserPrivate(String uid) =>
      firestore.collection('users_private').doc(uid).snapshots().map(_decode);

  /// 설정의 "대국 신청 받기"를 바꾼다. 보안 규칙이 본인의 이 필드만 허용한다.
  Future<void> updateChallengesEnabled(String uid, bool enabled) async {
    await firestore.collection('users_private').doc(uid).update({'challengesEnabled': enabled});
  }

  static UserPrivate? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return data == null ? null : UserPrivate.fromJson(data);
  }
}
