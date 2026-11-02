import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../config.dart';
import 'auth_repository.dart';
import 'config_repository.dart';
import 'connection_repository.dart';
import 'game_repository.dart';
import 'player_state_repository.dart';
import 'server_time_repository.dart';
import 'user_repository.dart';

/// 앱 수명 동안 쓰는 Repository. Firebase 초기화 뒤 `managers`보다 먼저 설정한다.
late AppRepositories repositories;

class AppRepositories {
  final AuthRepository authRepository;
  final ConfigRepository configRepository;
  final UserRepository userRepository;
  final PlayerStateRepository playerStateRepository;
  final GameRepository gameRepository;
  final ServerTimeRepository serverTimeRepository;
  final ConnectionRepository connectionRepository;

  AppRepositories({
    required this.authRepository,
    required this.configRepository,
    required this.userRepository,
    required this.playerStateRepository,
    required this.gameRepository,
    required this.serverTimeRepository,
    required this.connectionRepository,
  });

  factory AppRepositories.createDefault() {
    final firestore = FirebaseFirestore.instance;
    final functions = FirebaseFunctions.instanceFor(region: functionsRegion);
    final database = FirebaseDatabase.instance;
    return AppRepositories(
      authRepository: AuthRepository(auth: FirebaseAuth.instance),
      configRepository: ConfigRepository(firestore: firestore),
      userRepository: UserRepository(firestore: firestore, functions: functions),
      playerStateRepository: PlayerStateRepository(firestore: firestore),
      gameRepository: GameRepository(database: database, functions: functions, getServerUrl: getGameServerUrl),
      serverTimeRepository: ServerTimeRepository(database: database),
      connectionRepository: ConnectionRepository(database: database),
    );
  }
}
