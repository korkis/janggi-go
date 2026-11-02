import '../clock.dart';
import '../firebase/firestore_client.dart';
import '../firebase/rtdb_client.dart';
import 'active_games_repository.dart';
import 'archived_games_repository.dart';
import 'configs_repository.dart';
import 'nicknames_repository.dart';
import 'player_states_repository.dart';
import 'users_repository.dart';

/// 대국 서버의 repository 모음. 엔드포인트는 생성자로 필요한 repository를 받는다.
///
/// Firestore의 컬렉션과 하위 컬렉션, RTDB의 최상위 경로마다 repository를 하나씩 둔다(`docs/dev_rules.md`의 Repository).
class GameRepositories {
  final UsersRepository users;
  final ConfigsRepository configs;
  final NicknamesRepository nicknames;
  final PlayerStatesRepository playerStates;
  final ArchivedGamesRepository archivedGames;
  final ActiveGamesRepository activeGames;

  const GameRepositories({
    required this.users,
    required this.configs,
    required this.nicknames,
    required this.playerStates,
    required this.archivedGames,
    required this.activeGames,
  });

  factory GameRepositories.createDefault({
    required FirestoreClient firestore,
    required RtdbClient rtdb,
    Clock clock = utcNow,
  }) {
    return GameRepositories(
      users: UsersRepository(firestore: firestore),
      configs: ConfigsRepository(firestore: firestore, clock: clock),
      nicknames: NicknamesRepository(firestore: firestore),
      playerStates: PlayerStatesRepository(firestore: firestore),
      archivedGames: ArchivedGamesRepository(firestore: firestore),
      activeGames: ActiveGamesRepository(rtdb: rtdb),
    );
  }
}
