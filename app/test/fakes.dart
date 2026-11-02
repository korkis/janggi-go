import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/app_config.dart';
import 'package:janggigo/models/nickname_reject_reason.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/repositories/app_repositories.dart';
import 'package:janggigo/repositories/auth_repository.dart';
import 'package:janggigo/repositories/config_repository.dart';
import 'package:janggigo/repositories/user_repository.dart';
import 'package:janggigo/utils/app_exception.dart';

/// Firebase 없이 로그인 흐름을 확인하는 가짜 AuthRepository.
class FakeAuthRepository implements AuthRepository {
  final _uidController = StreamController<String?>.broadcast();
  String? _uid;

  /// 다음 로그인 시도가 이 오류로 실패한다.
  Object? nextSignInError;

  /// 마지막으로 쓴 로그인 방법. 'google', 'apple', 'email', 'emailSignUp'.
  String? lastSignInMethod;

  @override
  FirebaseAuth get auth => throw UnimplementedError();

  @override
  String? get currentUid => _uid;

  @override
  Stream<String?> uidChanges() async* {
    yield _uid;
    yield* _uidController.stream;
  }

  @override
  Future<void> signInWithGoogle() => _signIn('google', 'google-user');

  @override
  Future<void> signInWithApple() => _signIn('apple', 'apple-user');

  @override
  Future<void> signInWithEmail({required String email, required String password}) => _signIn('email', email);

  @override
  Future<void> createEmailAccount({required String email, required String password}) =>
      _signIn('emailSignUp', email);

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    _uid = null;
    _uidController.add(null);
  }

  Future<void> _signIn(String method, String uid) async {
    final error = nextSignInError;
    if (error != null) {
      nextSignInError = null;
      throw error;
    }
    lastSignInMethod = method;
    _uid = uid;
    _uidController.add(uid);
  }
}

class FakeUserRepository implements UserRepository {
  final FakeAuthRepository authRepository;
  final profiles = <String, UserProfile>{};

  /// 다른 사람이 이미 쓰는 닉네임.
  final takenNicknames = <String>{};

  FakeUserRepository(this.authRepository);

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  FirebaseFunctions get functions => throw UnimplementedError();

  @override
  Future<UserProfile?> getUser(String uid) async => profiles[uid];

  @override
  Future<NicknameAvailability> checkNickname(String nickname) async {
    if (takenNicknames.contains(nickname.toLowerCase())) {
      return const NicknameAvailability(available: false, reason: NicknameRejectReason.taken);
    }
    return const NicknameAvailability(available: true, reason: null);
  }

  @override
  Future<void> createProfile(String nickname) async {
    if (takenNicknames.contains(nickname.toLowerCase())) {
      throw AppException.fromNicknameRejectReason(NicknameRejectReason.taken);
    }
    final uid = authRepository.currentUid!;
    profiles[uid] = UserProfile(
      nickname: nickname,
      rankLevel: 1,
      stats: const UserStats(games: 0, wins: 0, losses: 0),
      createdAt: DateTime.utc(2026, 11, 2),
    );
  }
}

class FakeConfigRepository implements ConfigRepository {
  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  Future<AppConfig> getAppConfig() async => const AppConfig(
    disconnectLimitSeconds: 30,
    quickRematchLimit: 5,
    onlineUsersVisible: false,
    autoSanctionEnabled: false,
    heartbeatSeconds: 5,
  );
}

/// 각 테스트에서 위젯을 만들기 전에 `repositories`, `managers` 순서로 가짜를 설정한다.
({FakeAuthRepository auth, FakeUserRepository users}) setUpFakeApp() {
  final authRepository = FakeAuthRepository();
  final userRepository = FakeUserRepository(authRepository);
  repositories = AppRepositories(
    authRepository: authRepository,
    configRepository: FakeConfigRepository(),
    userRepository: userRepository,
  );
  managers = AppManagers.createDefault();
  return (auth: authRepository, users: userRepository);
}
