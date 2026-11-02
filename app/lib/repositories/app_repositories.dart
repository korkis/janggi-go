import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';
import 'auth_repository.dart';
import 'config_repository.dart';
import 'user_repository.dart';

/// 앱 수명 동안 쓰는 Repository. Firebase 초기화 뒤 `managers`보다 먼저 설정한다.
late AppRepositories repositories;

class AppRepositories {
  final AuthRepository authRepository;
  final ConfigRepository configRepository;
  final UserRepository userRepository;

  AppRepositories({required this.authRepository, required this.configRepository, required this.userRepository});

  factory AppRepositories.createDefault() {
    final firestore = FirebaseFirestore.instance;
    final functions = FirebaseFunctions.instanceFor(region: functionsRegion);
    return AppRepositories(
      authRepository: AuthRepository(auth: FirebaseAuth.instance),
      configRepository: ConfigRepository(firestore: firestore),
      userRepository: UserRepository(firestore: firestore, functions: functions),
    );
  }
}
