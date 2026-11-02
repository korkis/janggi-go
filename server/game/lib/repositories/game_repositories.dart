import '../clock.dart';
import '../firebase/firestore_client.dart';
import 'configs_repository.dart';
import 'users_repository.dart';

/// 대국 서버의 repository 모음. 엔드포인트는 생성자로 필요한 repository를 받는다.
///
/// Firestore의 컬렉션과 하위 컬렉션, RTDB의 최상위 경로마다 repository를 하나씩 둔다(`docs/dev_rules.md`의 Repository).
class GameRepositories {
  final UsersRepository users;
  final ConfigsRepository configs;

  const GameRepositories({required this.users, required this.configs});

  factory GameRepositories.createDefault({required FirestoreClient firestore, Clock clock = utcNow}) {
    return GameRepositories(
      users: UsersRepository(firestore: firestore),
      configs: ConfigsRepository(firestore: firestore, clock: clock),
    );
  }
}
