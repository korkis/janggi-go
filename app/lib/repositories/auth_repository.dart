import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../utils/app_exception.dart';

/// Firebase Auth 로그인과 로그아웃.
class AuthRepository {
  final FirebaseAuth auth;

  // GoogleSignIn.initialize는 앱 수명 동안 한 번만 부른다.
  Future<void>? _googleSignInInitialization;

  AuthRepository({required this.auth});

  /// 로그인한 사용자의 uid. 로그인하지 않았으면 null.
  String? get currentUid => auth.currentUser?.uid;

  /// 로그인 상태가 바뀔 때마다 uid를 보낸다. 처음 들을 때 지금 상태를 한 번 보낸다.
  Stream<String?> uidChanges() => auth.authStateChanges().map(_getUid);

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _runAuthCall(() => auth.signInWithPopup(GoogleAuthProvider()));
      return;
    }
    final googleSignIn = GoogleSignIn.instance;
    _googleSignInInitialization ??= googleSignIn.initialize(serverClientId: getGoogleServerClientId());
    await _googleSignInInitialization;
    final GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AppException(AppErrorCode.signInCanceled);
      }
      rethrow;
    }
    final credential = GoogleAuthProvider.credential(idToken: account.authentication.idToken);
    await _runAuthCall(() => auth.signInWithCredential(credential));
  }

  Future<void> signInWithApple() async {
    final provider = AppleAuthProvider()..addScope('email');
    if (kIsWeb) {
      await _runAuthCall(() => auth.signInWithPopup(provider));
      return;
    }
    await _runAuthCall(() => auth.signInWithProvider(provider));
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    await _runAuthCall(() => auth.signInWithEmailAndPassword(email: email, password: password));
  }

  Future<void> createEmailAccount({required String email, required String password}) async {
    await _runAuthCall(() => auth.createUserWithEmailAndPassword(email: email, password: password));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _runAuthCall(() => auth.sendPasswordResetEmail(email: email));
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  /// 남아 있는 로그인이 아직 쓸 수 있는지 토큰을 새로 받아 본다. 계정이 지워졌거나 막혔거나 토큰이 무효가 되었으면 false다.
  /// 네트워크 오류처럼 로그인과 상관없는 실패는 그대로 던진다.
  Future<bool> isSignInValid() async {
    final user = auth.currentUser;
    if (user == null) {
      return false;
    }
    try {
      await user.getIdToken(true);
      return true;
    } on FirebaseAuthException catch (error) {
      if (_invalidSignInErrorCodes.contains(error.code)) {
        return false;
      }
      rethrow;
    }
  }

  String? _getUid(User? user) => user?.uid;

  // 토큰을 새로 받을 때 이 오류가 나면 남은 로그인을 더 쓸 수 없다. 웹에서 Auth 에뮬레이터를 다시 띄우면 브라우저에 남은
  // 로그인은 invalid-refresh-token이 된다.
  static const _invalidSignInErrorCodes = {
    'invalid-refresh-token',
    'user-token-expired',
    'invalid-user-token',
    'user-not-found',
    'user-disabled',
    'invalid-credential',
  };

  /// Firebase Auth 호출의 오류 중 사용자에게 알릴 수 있는 것을 AppException으로 바꾼다.
  Future<void> _runAuthCall(Future<Object?> Function() call) async {
    try {
      await call();
    } on FirebaseAuthException catch (error) {
      final code = _getErrorCode(error.code);
      if (code == null) {
        rethrow;
      }
      throw AppException(code);
    }
  }

  AppErrorCode? _getErrorCode(String firebaseCode) => switch (firebaseCode) {
    'canceled' ||
    'web-context-canceled' ||
    'popup-closed-by-user' ||
    'cancelled-popup-request' => AppErrorCode.signInCanceled,
    'invalid-email' => AppErrorCode.invalidEmail,
    'invalid-credential' || 'wrong-password' || 'user-not-found' => AppErrorCode.wrongEmailOrPassword,
    'email-already-in-use' => AppErrorCode.emailAlreadyInUse,
    'weak-password' => AppErrorCode.weakPassword,
    'too-many-requests' => AppErrorCode.tooManyRequests,
    'network-request-failed' => AppErrorCode.network,
    _ => null,
  };
}
