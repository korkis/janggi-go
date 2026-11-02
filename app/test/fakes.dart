import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/active_game.dart';
import 'package:janggigo/models/app_config.dart';
import 'package:janggigo/models/connection.dart';
import 'package:janggigo/models/game_enums.dart';
import 'package:janggigo/models/nickname_reject_reason.dart';
import 'package:janggigo/models/player_state.dart';
import 'package:janggigo/models/room.dart';
import 'package:janggigo/models/user_private.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/repositories/app_repositories.dart';
import 'package:janggigo/repositories/auth_repository.dart';
import 'package:janggigo/repositories/config_repository.dart';
import 'package:janggigo/repositories/connection_repository.dart';
import 'package:janggigo/repositories/deep_link_repository.dart';
import 'package:janggigo/repositories/game_repository.dart';
import 'package:janggigo/repositories/player_state_repository.dart';
import 'package:janggigo/repositories/room_repository.dart';
import 'package:janggigo/repositories/server_time_repository.dart';
import 'package:janggigo/repositories/user_private_repository.dart';
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
  Stream<UserProfile?> watchUser(String uid) => Stream.value(profiles[uid]);

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

  /// `joinQuickQueue`가 돌려줄 대국. null이면 상대를 기다린다.
  String? joinQuickQueueResult;

  @override
  Future<String?> joinQuickQueue() async {
    await _record('joinQuickQueue');
    return joinQuickQueueResult;
  }

  @override
  Future<void> leaveQuickQueue() => _record('leaveQuickQueue');

  @override
  Future<String?> requestRematch(String gameId) async {
    await _record('requestRematch $gameId');
    return null;
  }

  @override
  Future<void> leaveResult(String gameId) => _record('leaveResult $gameId');

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

  /// 누군가 [uid]의 연결을 듣고 있는지.
  bool isWatchingConnections(String uid) => _getController(uid).hasListener;

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

/// 테스트가 `users_private` 문서를 직접 보내는 가짜 UserPrivateRepository.
class FakeUserPrivateRepository implements UserPrivateRepository {
  final _controllers = <String, StreamController<UserPrivate?>>{};
  final _latest = <String, UserPrivate?>{};

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  Stream<UserPrivate?> watchUserPrivate(String uid) async* {
    if (_latest.containsKey(uid)) {
      yield _latest[uid];
    }
    yield* _getController(uid).stream;
  }

  /// 대국 서버가 [uid]의 급수 진행을 바꾼 것처럼 보낸다.
  void emit(String uid, UserPrivate? userPrivate) {
    _latest[uid] = userPrivate;
    _getController(uid).add(userPrivate);
  }

  StreamController<UserPrivate?> _getController(String uid) =>
      _controllers.putIfAbsent(uid, StreamController<UserPrivate?>.broadcast);
}

class FakeServerTimeRepository implements ServerTimeRepository {
  @override
  FirebaseDatabase get database => throw UnimplementedError();

  @override
  Stream<Duration> watchServerTimeOffset() => Stream.value(Duration.zero);
}

/// 대국 서버의 방 API 호출을 기록하고, 테스트가 `rooms` 문서와 방 목록을 직접 보내는 가짜 RoomRepository.
class FakeRoomRepository implements RoomRepository {
  final _controllers = <String, StreamController<Room?>>{};
  final _latest = <String, Room?>{};

  /// 부른 API와 파라미터. 예: `joinRoom room1`, `createRoom random listed null null`.
  final calls = <String>[];

  /// 다음 대국 서버 호출이 이 오류로 실패한다.
  Object? nextError;

  /// 방 목록이 돌려줄 방.
  var rooms = <({String id, Room room})>[];

  /// `createRoom`이 돌려줄 방 ID.
  var createdRoomId = 'room1';

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  FirebaseFunctions get functions => throw UnimplementedError();

  @override
  Uri Function() get getServerUrl => throw UnimplementedError();

  @override
  Stream<Room?> watchRoom(String roomId) async* {
    if (_latest.containsKey(roomId)) {
      yield _latest[roomId];
    }
    yield* _getController(roomId).stream;
  }

  @override
  Future<Room?> getRoom(String roomId) async => _latest[roomId];

  @override
  Future<List<({String id, Room room})>> getRooms() async {
    await _record('getRooms');
    return rooms;
  }

  /// 대국 서버가 방을 바꾼 것처럼 보낸다.
  void emit(String roomId, Room? room) {
    _latest[roomId] = room;
    _getController(roomId).add(room);
  }

  @override
  Future<String> createRoom({
    required SideChoice hostSide,
    required HandicapRemover? handicapRemover,
    required List<HandicapPiece>? handicapPieces,
    required bool listed,
    required RankRange? rankRange,
  }) async {
    final pieces = handicapPieces?.map((piece) => piece.name).join(',');
    final range = rankRange == null ? null : '${rankRange.min}-${rankRange.max}';
    await _record(
      'createRoom ${hostSide.name} ${listed ? 'listed' : 'unlisted'} ${handicapRemover?.name} $pieces $range',
    );
    return createdRoomId;
  }

  @override
  Future<void> joinRoom(String roomId) => _record('joinRoom $roomId');

  @override
  Future<void> leaveRoom(String roomId) => _record('leaveRoom $roomId');

  @override
  Future<void> kickGuest(String roomId) => _record('kickGuest $roomId');

  @override
  Future<void> startRoomGame(String roomId) => _record('startRoomGame $roomId');

  Future<void> _record(String call) async {
    calls.add(call);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  StreamController<Room?> _getController(String roomId) =>
      _controllers.putIfAbsent(roomId, StreamController<Room?>.broadcast);
}

/// 테스트가 앱으로 들어오는 주소와 플레이 스토어 설치 정보를 직접 보내는 가짜 DeepLinkRepository.
class FakeDeepLinkRepository implements DeepLinkRepository {
  final _controller = StreamController<Uri>.broadcast();

  /// 설치 뒤 처음 한 번 돌려줄 설치 정보.
  String? installReferrer;

  @override
  AppLinks get appLinks => throw UnimplementedError();

  @override
  Stream<Uri> watchLinks() => _controller.stream;

  /// 링크를 누른 것처럼 보낸다.
  void emit(Uri uri) => _controller.add(uri);

  @override
  Future<String?> takeInstallReferrer() async {
    final referrer = installReferrer;
    installReferrer = null;
    return referrer;
  }
}

/// [setUpFakeApp]이 설정한 가짜 repository들.
typedef FakeApp = ({
  FakeAuthRepository auth,
  FakeUserRepository users,
  FakeUserPrivateRepository userPrivates,
  FakePlayerStateRepository playerStates,
  FakeGameRepository games,
  FakeConnectionRepository connections,
  FakeRoomRepository rooms,
  FakeDeepLinkRepository deepLinks,
});

/// 각 테스트에서 위젯을 만들기 전에 `repositories`, `managers` 순서로 가짜를 설정한다.
FakeApp setUpFakeApp() {
  final authRepository = FakeAuthRepository();
  final userRepository = FakeUserRepository(authRepository);
  final userPrivateRepository = FakeUserPrivateRepository();
  final playerStateRepository = FakePlayerStateRepository();
  final gameRepository = FakeGameRepository();
  final connectionRepository = FakeConnectionRepository();
  final roomRepository = FakeRoomRepository();
  final deepLinkRepository = FakeDeepLinkRepository();
  repositories = AppRepositories(
    authRepository: authRepository,
    configRepository: FakeConfigRepository(),
    userRepository: userRepository,
    userPrivateRepository: userPrivateRepository,
    playerStateRepository: playerStateRepository,
    gameRepository: gameRepository,
    serverTimeRepository: FakeServerTimeRepository(),
    connectionRepository: connectionRepository,
    roomRepository: roomRepository,
    deepLinkRepository: deepLinkRepository,
  );
  managers = AppManagers.createDefault();
  return (
    auth: authRepository,
    users: userRepository,
    userPrivates: userPrivateRepository,
    playerStates: playerStateRepository,
    games: gameRepository,
    connections: connectionRepository,
    rooms: roomRepository,
    deepLinks: deepLinkRepository,
  );
}
