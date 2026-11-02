import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/active_game.dart';
import 'package:janggigo/models/app_config.dart';
import 'package:janggigo/models/connection.dart';
import 'package:janggigo/models/game_enums.dart';
import 'package:janggigo/models/nickname_reject_reason.dart';
import 'package:janggigo/models/player_state.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/repositories/app_repositories.dart';
import 'package:janggigo/repositories/auth_repository.dart';
import 'package:janggigo/repositories/config_repository.dart';
import 'package:janggigo/repositories/connection_repository.dart';
import 'package:janggigo/repositories/game_repository.dart';
import 'package:janggigo/repositories/player_state_repository.dart';
import 'package:janggigo/repositories/server_time_repository.dart';
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
  Future<void> createEmailAccount({required String email, required String password}) => _signIn('emailSignUp', email);

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

class FakePlayerStateRepository implements PlayerStateRepository {
  final _controllers = <String, StreamController<PlayerState?>>{};

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  Stream<PlayerState?> watchPlayerState(String uid) => _getController(uid).stream;

  /// 대국 서버가 [uid]의 상태를 바꾼 것처럼 보낸다.
  void emit(String uid, PlayerState? state) => _getController(uid).add(state);

  StreamController<PlayerState?> _getController(String uid) =>
      _controllers.putIfAbsent(uid, StreamController<PlayerState?>.broadcast);
}

/// 대국 서버 호출을 기록하고, 테스트가 RTDB 대국 값을 직접 보내는 가짜 GameRepository.
class FakeGameRepository implements GameRepository {
  final _controllers = <String, StreamController<ActiveGame?>>{};
  final _latest = <String, ActiveGame?>{};

  /// 부른 API와 파라미터. 예: `playMove gameId 0 a4b4`.
  final calls = <String>[];

  /// 다음 대국 서버 호출이 이 오류로 실패한다.
  Object? nextError;

  /// `playMove`를 받으면 끝날 때까지 기다린다. null이면 바로 성공한다.
  Completer<void>? playMoveGate;

  @override
  FirebaseDatabase get database => throw UnimplementedError();

  @override
  FirebaseFunctions get functions => throw UnimplementedError();

  @override
  Uri Function() get getServerUrl => throw UnimplementedError();

  @override
  Stream<ActiveGame?> watchGame(String gameId) async* {
    if (_latest.containsKey(gameId)) {
      yield _latest[gameId];
    }
    yield* _getController(gameId).stream;
  }

  /// 대국 서버가 RTDB에 쓴 것처럼 [json]을 보낸다.
  void emit(String gameId, Map<String, dynamic>? json) {
    final game = json == null ? null : ActiveGame.fromJson(json);
    _latest[gameId] = game;
    _getController(gameId).add(game);
  }

  @override
  Future<void> createDevGame({required String opponentNickname, required SideChoice side}) =>
      _record('createDevGame $opponentNickname ${side.name}');

  @override
  Future<void> setFormation(String gameId, Formation formation, {required bool confirmed}) =>
      _record('setFormation $gameId ${formation.name} $confirmed');

  @override
  Future<void> playMove(String gameId, {required int moveIndex, required Move move}) async {
    await _record('playMove $gameId $moveIndex $move');
    await playMoveGate?.future;
  }

  @override
  Future<void> resign(String gameId) => _record('resign $gameId');

  @override
  Future<void> checkGame(String gameId) => _record('checkGame $gameId');

  Future<void> _record(String call) async {
    calls.add(call);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  StreamController<ActiveGame?> _getController(String gameId) =>
      _controllers.putIfAbsent(gameId, StreamController<ActiveGame?>.broadcast);
}

/// 접속 상태 쓰기를 기록하고, 테스트가 RTDB 연결 상태와 상대의 연결을 직접 보내는 가짜 ConnectionRepository.
/// 처음에는 RTDB에 연결되어 있다.
class FakeConnectionRepository implements ConnectionRepository {
  final _connectedController = StreamController<bool>.broadcast();
  final _connectionsControllers = <String, StreamController<List<Connection>>>{};
  var _connected = true;
  var _createdCount = 0;

  /// 쓴 것. 예: `create opp true`, `foreground opp c1`, `background opp c1`, `lastSeenAt opp c1`.
  final writes = <String>[];

  @override
  FirebaseDatabase get database => throw UnimplementedError();

  @override
  Stream<bool> watchConnected() async* {
    yield _connected;
    yield* _connectedController.stream;
  }

  /// 이 기기의 RTDB 연결이 바뀐 것처럼 보낸다.
  void setConnected(bool connected) {
    _connected = connected;
    _connectedController.add(connected);
  }

  @override
  Stream<List<Connection>> watchConnections(String uid) => _getController(uid).stream;

  /// [uid]의 연결이 바뀐 것처럼 보낸다.
  void emitConnections(String uid, List<Connection> connections) => _getController(uid).add(connections);

  @override
  Future<String> createConnection(String uid, {required bool foreground}) async {
    writes.add('create $uid $foreground');
    _createdCount++;
    return 'c$_createdCount';
  }

  @override
  Future<void> markForeground(String uid, String connectionId) async => writes.add('foreground $uid $connectionId');

  @override
  Future<void> markBackground(String uid, String connectionId) async => writes.add('background $uid $connectionId');

  @override
  Future<void> updateLastSeenAt(String uid, String connectionId) async => writes.add('lastSeenAt $uid $connectionId');

  StreamController<List<Connection>> _getController(String uid) =>
      _connectionsControllers.putIfAbsent(uid, StreamController<List<Connection>>.broadcast);
}

class FakeServerTimeRepository implements ServerTimeRepository {
  @override
  FirebaseDatabase get database => throw UnimplementedError();

  @override
  Stream<Duration> watchServerTimeOffset() => Stream.value(Duration.zero);
}

/// 각 테스트에서 위젯을 만들기 전에 `repositories`, `managers` 순서로 가짜를 설정한다.
({
  FakeAuthRepository auth,
  FakeUserRepository users,
  FakePlayerStateRepository playerStates,
  FakeGameRepository games,
  FakeConnectionRepository connections,
})
setUpFakeApp() {
  final authRepository = FakeAuthRepository();
  final userRepository = FakeUserRepository(authRepository);
  final playerStateRepository = FakePlayerStateRepository();
  final gameRepository = FakeGameRepository();
  final connectionRepository = FakeConnectionRepository();
  repositories = AppRepositories(
    authRepository: authRepository,
    configRepository: FakeConfigRepository(),
    userRepository: userRepository,
    playerStateRepository: playerStateRepository,
    gameRepository: gameRepository,
    serverTimeRepository: FakeServerTimeRepository(),
    connectionRepository: connectionRepository,
  );
  managers = AppManagers.createDefault();
  return (
    auth: authRepository,
    users: userRepository,
    playerStates: playerStateRepository,
    games: gameRepository,
    connections: connectionRepository,
  );
}
