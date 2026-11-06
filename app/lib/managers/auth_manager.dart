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

  /// 닉네임을 바꾸고 바뀐 프로필을 다시 읽는다. [coinCost]는 사용자에게 보여준 값이다. 무료 변경이면 null.
  Future<void> changeNickname(String nickname, {int? coinCost}) async {
    await repositories.userRepository.changeNickname(nickname, coinCost: coinCost);
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

  /// 회원 탈퇴하고 로그아웃한다(`docs/server.md`의 회원 탈퇴).
  Future<void> deleteAccount() async {
    await repositories.userRepository.deleteAccount();
    await signOut();
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

  /// 프로필을 읽는다. 실패했는데 남아 있는 로그인을 더 쓸 수 없으면(계정이 지워졌거나 토큰이 무효) 로그아웃하고 오류 없이
  /// 끝낸다. 웹은 지난 로그인을 브라우저에 남겨 두므로 그 로그인으로 읽기가 계속 거절될 수 있다. 네트워크 오류처럼 로그인이
  /// 멀쩡한 실패는 로그인을 두고 오류를 던진다. 프로필이 없을 때도 로그인을 확인한다. 다른 기기에서 탈퇴했으면 프로필이 없는 것으로
  /// 읽히는데, 닉네임 정하기로 보내지 않기 위해서다.
  Future<void> _loadProfile(String uid) async {
    try {
      final profile = await repositories.userRepository.getUser(uid);
      if (_uid != uid) {
        return;
      }
      if (profile == null && await _isSignInInvalid()) {
        _profileLoad = null;
        developer.log('AuthManager 프로필이 없고 로그인이 무효라 로그아웃');
        await signOut();
        return;
      }
      _profile = profile;
      notifyListeners();
    } catch (_) {
      if (_uid != uid) {
        rethrow;
      }
      _profileLoad = null;
      if (await _isSignInInvalid()) {
        developer.log('AuthManager 남은 로그인이 무효라 로그아웃');
        await signOut();
        return;
      }
      rethrow;
    }
  }

  /// 남은 로그인이 무효인지. 확인하다 실패하면(네트워크 오류 등) 무효로 보지 않는다.
  Future<bool> _isSignInInvalid() async {
    try {
      return !await repositories.authRepository.isSignInValid();
    } catch (error, stackTrace) {
      developer.log('AuthRepository.isSignInValid 실패', error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
