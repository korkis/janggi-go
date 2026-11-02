import '../clock.dart';
import '../firebase/firestore_client.dart';
import '../firebase/rtdb_client.dart';
import 'active_games_repository.dart';
import 'archived_games_repository.dart';
import 'configs_repository.dart';
import 'connections_repository.dart';
import 'nicknames_repository.dart';
import 'player_states_repository.dart';
import 'quick_queue_repository.dart';
import 'ratings_repository.dart';
import 'rooms_repository.dart';
import 'users_private_repository.dart';
import 'users_repository.dart';

/// 대국 서버의 repository 모음. 엔드포인트는 생성자로 필요한 repository를 받는다.
///
/// Firestore의 컬렉션과 하위 컬렉션, RTDB의 최상위 경로마다 repository를 하나씩 둔다(`docs/dev_rules.md`의 Repository).
class GameRepositories {
  final UsersRepository users;
  final UsersPrivateRepository usersPrivate;
  final ConfigsRepository configs;
  final NicknamesRepository nicknames;
  final PlayerStatesRepository playerStates;
  final RatingsRepository ratings;
  final QuickQueueRepository quickQueue;
  final RoomsRepository rooms;
  final ArchivedGamesRepository archivedGames;
  final ActiveGamesRepository activeGames;
  final ConnectionsRepository connections;

  const GameRepositories({
    required this.users,
    required this.usersPrivate,
    required this.configs,
    required this.nicknames,
    required this.playerStates,
    required this.ratings,
    required this.quickQueue,
    required this.rooms,
    required this.archivedGames,
    required this.activeGames,
    required this.connections,
  });

  factory GameRepositories.createDefault({
    required FirestoreClient firestore,
    required RtdbClient rtdb,
    Clock clock = utcNow,
  }) {
    return GameRepositories(
      users: UsersRepository(firestore: firestore),
      usersPrivate: UsersPrivateRepository(firestore: firestore),
      configs: ConfigsRepository(firestore: firestore, clock: clock),
      nicknames: NicknamesRepository(firestore: firestore),
      playerStates: PlayerStatesRepository(firestore: firestore),
      ratings: RatingsRepository(firestore: firestore),
      quickQueue: QuickQueueRepository(firestore: firestore),
      rooms: RoomsRepository(firestore: firestore),
      archivedGames: ArchivedGamesRepository(firestore: firestore),
      activeGames: ActiveGamesRepository(rtdb: rtdb),
      connections: ConnectionsRepository(rtdb: rtdb),
    );
  }
}
