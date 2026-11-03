import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../repositories/app_repositories.dart';

/// 로그인 상태와 내 공개 프로필.
///
/// 로그인했어도 첫 가입의 닉네임 정하기를 마치기 전에는 [profile]이 null이다.
class AuthManager extends ChangeNotifier {
  StreamSubscription<String?>? _uidSubscription;

  String? _uid;
  UserProfile? _profile;

  // 지금 [_uid]의 프로필 읽기. 끝났으면 완료된 Future이고, 실패했으면 다음에 다시 읽도록 null로 돌린다.
  Future<void>? _profileLoad;

  AuthManager() {
    _uidSubscription = repositories.authRepository.uidChanges().listen(_onUidChanged);
  }

  @override
  void dispose() {
    _uidSubscription?.cancel();
    super.dispose();
  }

  String? get uid => _uid;
  UserProfile? get profile => _profile;
  bool get signedIn => _uid != null;

  /// 로그인했고 프로필을 아직 읽는 중이다.
  bool get profileLoading => _uid != null && _profile == null && _profileLoad != null;

  Future<void> signInWithGoogle() async {
    await repositories.authRepository.signInWithGoogle();
    await ensureProfileLoaded();
  }

  Future<void> signInWithApple() async {
    await repositories.authRepository.signInWithApple();
    await ensureProfileLoaded();
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    await repositories.authRepository.signInWithEmail(email: email, password: password);
    await ensureProfileLoaded();
  }

  Future<void> createEmailAccount({required String email, required String password}) async {
    await repositories.authRepository.createEmailAccount(email: email, password: password);
    await ensureProfileLoaded();
  }

  /// 첫 가입의 닉네임을 정하고 만들어진 프로필을 읽는다.
  Future<void> createProfile(String nickname) async {
    await repositories.userRepository.createProfile(nickname);
    final uid = _uid;
    if (uid == null) {
      throw StateError('로그인하지 않은 상태에서 createProfile을 불렀습니다');
    }
    _profileLoad = _loadProfile(uid);
    await _profileLoad;
  }

  /// 닉네임을 바꾸고 바뀐 프로필을 다시 읽는다.
  Future<void> changeNickname(String nickname) async {
    await repositories.userRepository.changeNickname(nickname);
    final uid = _uid;
    if (uid == null) {
      throw StateError('로그인하지 않은 상태에서 changeNickname을 불렀습니다');
    }
    _profileLoad = _loadProfile(uid);
    await _profileLoad;
  }

  Future<void> signOut() async {
    await repositories.authRepository.signOut();
    await _syncUid(null);
  }

  /// 지금 로그인한 사용자의 프로필을 다 읽을 때까지 기다린다. 로그인 직후 프로필이 있는지 볼 때 쓴다.
  Future<void> ensureProfileLoaded() => _syncUid(repositories.authRepository.currentUid);

  void _onUidChanged(String? uid) {
    _syncUid(uid).catchError(_onProfileLoadError);
  }

  void _onProfileLoadError(Object error, StackTrace stackTrace) {
    developer.log('AuthManager 프로필 읽기 실패', error: error, stackTrace: stackTrace);
  }

  Future<void> _syncUid(String? uid) {
    final profileLoad = _profileLoad;
    if (uid == _uid && (uid == null || profileLoad != null)) {
      return profileLoad ?? Future.value();
    }
    _uid = uid;
    _profile = null;
    if (uid == null) {
      _profileLoad = null;
      notifyListeners();
      return Future.value();
    }
    final load = _loadProfile(uid);
    _profileLoad = load;
    notifyListeners();
    return load;
  }

  Future<void> _loadProfile(String uid) async {
    try {
      final profile = await repositories.userRepository.getUser(uid);
      if (_uid != uid) {
        return;
      }
      _profile = profile;
      notifyListeners();
    } catch (_) {
      if (_uid == uid) {
        _profileLoad = null;
      }
      rethrow;
    }
  }
}
