import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../config.dart';
import 'archived_game_repository.dart';
import 'auth_repository.dart';
import 'challenge_repository.dart';
import 'chat_repository.dart';
import 'config_repository.dart';
import 'connection_repository.dart';
import 'deep_link_repository.dart';
import 'game_repository.dart';
import 'online_user_repository.dart';
import 'player_state_repository.dart';
import 'room_repository.dart';
import 'server_time_repository.dart';
import 'spectate_list_repository.dart';
import 'spectator_repository.dart';
import 'user_block_repository.dart';
import 'user_private_repository.dart';
import 'user_repository.dart';

/// 앱 수명 동안 쓰는 Repository. Firebase 초기화 뒤 `managers`보다 먼저 설정한다.
late AppRepositories repositories;

class AppRepositories {
  final AuthRepository authRepository;
  final ConfigRepository configRepository;
  final UserRepository userRepository;
  final UserPrivateRepository userPrivateRepository;
  final PlayerStateRepository playerStateRepository;
  final GameRepository gameRepository;
  final ServerTimeRepository serverTimeRepository;
  final ConnectionRepository connectionRepository;
  final RoomRepository roomRepository;
  final DeepLinkRepository deepLinkRepository;
  final OnlineUserRepository onlineUserRepository;
  final ChallengeRepository challengeRepository;
  final UserBlockRepository userBlockRepository;
  final SpectateListRepository spectateListRepository;
  final SpectatorRepository spectatorRepository;
  final ChatRepository chatRepository;
  final ArchivedGameRepository archivedGameRepository;

  AppRepositories({
    required this.authRepository,
    required this.configRepository,
    required this.userRepository,
    required this.userPrivateRepository,
    required this.playerStateRepository,
    required this.gameRepository,
    required this.serverTimeRepository,
    required this.connectionRepository,
    required this.roomRepository,
    required this.deepLinkRepository,
    required this.onlineUserRepository,
    required this.challengeRepository,
    required this.userBlockRepository,
    required this.spectateListRepository,
    required this.spectatorRepository,
    required this.chatRepository,
    required this.archivedGameRepository,
  });

  factory AppRepositories.createDefault() {
    final firestore = FirebaseFirestore.instance;
    final functions = FirebaseFunctions.instanceFor(region: functionsRegion);
    final database = FirebaseDatabase.instance;
    return AppRepositories(
      authRepository: AuthRepository(auth: FirebaseAuth.instance),
      configRepository: ConfigRepository(firestore: firestore),
      userRepository: UserRepository(firestore: firestore, functions: functions),
      userPrivateRepository: UserPrivateRepository(firestore: firestore),
      playerStateRepository: PlayerStateRepository(firestore: firestore),
      gameRepository: GameRepository(database: database, functions: functions, getServerUrl: getGameServerUrl),
      serverTimeRepository: ServerTimeRepository(database: database),
      connectionRepository: ConnectionRepository(database: database),
      roomRepository: RoomRepository(firestore: firestore, functions: functions, getServerUrl: getGameServerUrl),
      deepLinkRepository: DeepLinkRepository(appLinks: AppLinks()),
      onlineUserRepository: OnlineUserRepository(
        database: database,
        functions: functions,
        getServerUrl: getGameServerUrl,
      ),
      challengeRepository: ChallengeRepository(
        firestore: firestore,
        functions: functions,
        getServerUrl: getGameServerUrl,
      ),
      userBlockRepository: UserBlockRepository(firestore: firestore),
      spectateListRepository: SpectateListRepository(database: database),
      spectatorRepository: SpectatorRepository(database: database),
      chatRepository: ChatRepository(database: database, functions: functions),
      archivedGameRepository: ArchivedGameRepository(firestore: firestore),
    );
  }
}
