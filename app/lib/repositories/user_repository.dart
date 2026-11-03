import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/nickname_reject_reason.dart';
import '../models/user_profile.dart';
import '../utils/app_exception.dart';

/// Firestore `users` 컬렉션과 프로필·닉네임 Callable.
class UserRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  UserRepository({required this.firestore, required this.functions});

  CollectionReference<Map<String, dynamic>> get _users => firestore.collection('users');

  /// 공개 프로필. 아직 닉네임을 정하지 않았으면 null.
  Future<UserProfile?> getUser(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return UserProfile.fromJson(data);
  }

  /// 공개 프로필을 듣는다. 급수처럼 대국 서버가 바꾸는 값을 바로 보여줄 때 쓴다. 프로필이 없으면 null을 보낸다.
  Stream<UserProfile?> watchUser(String uid) => _users.doc(uid).snapshots().map(_decode);

  static UserProfile? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return data == null ? null : UserProfile.fromJson(data);
  }

  /// 닉네임 정하기 화면에서 입력하는 동안 [nickname]을 쓸 수 있는지 서버에 묻는다.
  Future<NicknameAvailability> checkNickname(String nickname) async {
    final result = await functions.httpsCallable('checkNickname').call<Map<String, dynamic>>({'nickname': nickname});
    final data = result.data;
    return NicknameAvailability(
      available: data['available'] == true,
      reason: NicknameRejectReason.fromName(data['reason']),
    );
  }

  /// 첫 가입의 닉네임을 정하고 프로필을 만든다. 서버가 닉네임을 거절하면 그 이유의 AppException을 던진다.
  Future<void> createProfile(String nickname) async {
    try {
      await functions.httpsCallable('createProfile').call<Object?>({'nickname': nickname});
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final reason = details is Map ? NicknameRejectReason.fromName(details['code']) : null;
      if (reason == null) {
        rethrow;
      }
      throw AppException.fromNicknameRejectReason(reason);
    }
  }

  /// 닉네임을 바꾼다(`docs/screens.md`의 내 정보). 서버가 거절하면 그 이유의 AppException을 던진다.
  Future<void> changeNickname(String nickname) async {
    try {
      await functions.httpsCallable('changeNickname').call<Object?>({'nickname': nickname});
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final code = details is Map ? details['code'] : null;
      final reason = NicknameRejectReason.fromName(code);
      if (reason != null) {
        throw AppException.fromNicknameRejectReason(reason);
      }
      switch (code) {
        case 'nicknameChangeCooldown':
          throw const AppException(AppErrorCode.nicknameChangeCooldown);
        case 'nicknameChangeNotFree':
          throw const AppException(AppErrorCode.nicknameChangeNotFree);
      }
      rethrow;
    }
  }
}
