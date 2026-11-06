import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/active_game.dart';
import 'package:janggigo/models/app_language.dart';
import 'package:janggigo/models/archived_game.dart';
import 'package:janggigo/models/app_config.dart';
import 'package:janggigo/models/challenge.dart';
import 'package:janggigo/models/chat_message.dart';
import 'package:janggigo/models/coin_wallet.dart';
import 'package:janggigo/models/connection.dart';
import 'package:janggigo/models/game_enums.dart';
import 'package:janggigo/models/nickname_reject_reason.dart';
import 'package:janggigo/models/online_user.dart';
import 'package:janggigo/models/player_state.dart';
import 'package:janggigo/models/room.dart';
import 'package:janggigo/models/sign_in_method.dart';
import 'package:janggigo/models/spectate_list_entry.dart';
import 'package:janggigo/models/user_private.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/repositories/app_repositories.dart';
import 'package:janggigo/repositories/archived_game_repository.dart';
import 'package:janggigo/repositories/auth_repository.dart';
import 'package:janggigo/repositories/challenge_repository.dart';
import 'package:janggigo/repositories/chat_repository.dart';
import 'package:janggigo/repositories/coin_wallet_repository.dart';
import 'package:janggigo/repositories/config_repository.dart';
import 'package:janggigo/repositories/connection_repository.dart';
import 'package:janggigo/repositories/deep_link_repository.dart';
import 'package:janggigo/repositories/device_settings_repository.dart';
import 'package:janggigo/repositories/game_repository.dart';
import 'package:janggigo/repositories/online_user_repository.dart';
import 'package:janggigo/repositories/player_state_repository.dart';
import 'package:janggigo/repositories/room_repository.dart';
import 'package:janggigo/repositories/server_time_repository.dart';
import 'package:janggigo/repositories/spectate_list_repository.dart';
import 'package:janggigo/repositories/spectator_repository.dart';
import 'package:janggigo/repositories/user_block_repository.dart';
import 'package:janggigo/repositories/user_private_repository.dart';
import 'package:janggigo/repositories/user_repository.dart';
import 'package:janggigo/utils/app_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase 없이 로그인 흐름을 확인하는 가짜 AuthRepository.
class FakeAuthRepository implements AuthRepository {
  final _uidController = StreamController<String?>.broadcast();
  String? _uid;

  /// 다음 로그인 시도가 이 오류로 실패한다.
  Object? nextSignInError;

  /// [isSignInValid]가 돌려줄 값. 남아 있는 로그인이 무효가 된 경우를 흉내 낸다.
  bool signInValid = true;

  /// 마지막으로 쓴 로그인 방법. 'google', 'apple', 'email', 'emailSignUp'.
  String? lastSignInMethod;

  @override
  FirebaseAuth get auth => throw UnimplementedError();

  @override
  String? get currentUid => _uid;

  /// [getSignInMethod]가 돌려줄 값.
  SignInMethod? signInMethod;

  @override
  SignInMethod? getSignInMethod() => signInMethod;

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

  /// [revokeAppleSignIn]을 부른 횟수.
  var appleRevokeCalls = 0;

  /// 다음 [revokeAppleSignIn]이 이 오류로 실패한다.
  Object? nextAppleRevokeError;

  @override
  Future<void> revokeAppleSignIn() async {
    appleRevokeCalls++;
    final error = nextAppleRevokeError;
    if (error != null) {
      nextAppleRevokeError = null;
      throw error;
    }
  }

  @override
  Future<bool> isSignInValid() async => _uid != null && signInValid;

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

  /// 다음 [getUser]가 이 오류로 실패한다.
  Object? nextGetUserError;

  FakeUserRepository(this.authRepository);

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  FirebaseFunctions get functions => throw UnimplementedError();

  @override
  Future<UserProfile?> getUser(String uid) async {
    final error = nextGetUserError;
    if (error != null) {
      nextGetUserError = null;
      throw error;
    }
    return profiles[uid];
  }

  // [updateProfile]로 바꾼 사용자의 uid.
  final _profileChanges = StreamController<String>.broadcast();

  /// [uid]의 프로필을 바꾸고 듣고 있는 쪽에 알린다. 대국 서버가 전적을 더한 것처럼 쓸 때 쓴다.
  void updateProfile(String uid, UserProfile profile) {
    profiles[uid] = profile;
    _profileChanges.add(uid);
  }

  @override
  Stream<UserProfile?> watchUser(String uid) async* {
    yield profiles[uid];
    await for (final changed in _profileChanges.stream) {
      if (changed == uid) {
        yield profiles[uid];
      }
    }
  }

  @override
  Future<NicknameAvailability> checkNickname(String nickname) async {
    if (takenNicknames.contains(nickname.toLowerCase())) {
      return const NicknameAvailability(available: false, reason: NicknameRejectReason.taken);
    }
    return const NicknameAvailability(available: true, reason: null);
  }

  @override
  Future<void> createProfile(String nickname) async {
    final error = nextCreateProfileError;
    if (error != null) {
      nextCreateProfileError = null;
      throw error;
    }
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

  /// 다음 [deleteAccount]가 이 오류로 실패한다.
  Object? nextDeleteAccountError;

  /// 탈퇴한 사용자.
  final deletedAccounts = <String>[];

  @override
  Future<void> deleteAccount() async {
    final error = nextDeleteAccountError;
    if (error != null) {
      nextDeleteAccountError = null;
      throw error;
    }
    deletedAccounts.add(authRepository.currentUid!);
  }

  /// 다음 [createProfile]이 이 오류로 실패한다.
  Object? nextCreateProfileError;

  /// 바꾼 닉네임. 예: `me 장기신`.
  final nicknameChanges = <String>[];

  /// 마지막 닉네임 바꾸기에 보낸 엽전 값.
  int? lastNicknameCoinCost;

  /// 다음 닉네임 바꾸기가 이 오류로 실패한다.
  Object? nextChangeError;

  @override
  Future<void> changeNickname(String nickname, {int? coinCost}) async {
    lastNicknameCoinCost = coinCost;
    final error = nextChangeError;
    if (error != null) {
      nextChangeError = null;
      throw error;
    }
    if (takenNicknames.contains(nickname.toLowerCase())) {
      throw AppException.fromNicknameRejectReason(NicknameRejectReason.taken);
    }
    final uid = authRepository.currentUid!;
    final profile = profiles[uid]!;
    nicknameChanges.add('$uid $nickname');
    profiles[uid] = UserProfile(
      nickname: nickname,
      rankLevel: profile.rankLevel,
      stats: profile.stats,
      createdAt: profile.createdAt,
    );
  }
}

class FakeConfigRepository implements ConfigRepository {
  /// `configs/app.onlineUsersVisible`.
  var onlineUsersVisible = false;

  /// `configs/app.timeExtensionEnabled`.
  var timeExtensionEnabled = true;

  /// `configs/app.gamePracticeEnabled`.
  var gamePracticeEnabled = true;

  /// `configs/app.chatEnabled`.
  var chatEnabled = true;

  /// `configs/app.signupEnabled`.
  var signupEnabled = true;

  /// `configs/app.webEnabled`.
  var webEnabled = true;

  /// `configs/app.minAppVersion`.
  var minAppVersion = '1.0.0';

  /// `configs/app.serviceNotice`.
  ServiceNotice? serviceNotice;

  // [emitConfig]를 듣는 쪽에 알린다.
  final _changes = StreamController<void>.broadcast();

  /// 운영자가 설정을 바꾼 것처럼 위 값을 보낸다.
  void emitConfig() => _changes.add(null);

  @override
  Stream<AppConfig?> watchAppConfig() async* {
    yield await getAppConfig();
    await for (final _ in _changes.stream) {
      yield await getAppConfig();
    }
  }

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  Future<AppConfig> getAppConfig() async => AppConfig(
    disconnectLimitSeconds: 30,
    quickRematchLimit: 5,
    onlineUsersVisible: onlineUsersVisible,
    autoSanctionEnabled: false,
    heartbeatSeconds: 5,
    entryFeeEnabled: true,
    coinSignupBonus: 300,
    coinEntryFee: 10,
    coinWinReward: 12,
    coinLossReward: 0,
    coinAttendanceReward: 30,
    coinAttendanceStreakReward: 100,
    coinNicknameChangeCost: 300,
    timeExtensionEnabled: timeExtensionEnabled,
    gamePracticeEnabled: gamePracticeEnabled,
    coinTimeExtensionCost: 30,
    coinGamePracticeCost: 30,
    chatEnabled: chatEnabled,
    signupEnabled: signupEnabled,
    webEnabled: webEnabled,
    minAppVersion: minAppVersion,
    serviceNotice: serviceNotice,
  );
}

class FakeCoinWalletRepository implements CoinWalletRepository {
  final _controllers = <String, StreamController<CoinWallet?>>{};
  final _latest = <String, CoinWallet?>{};

  /// 다음 출석 결과. 기본은 이미 받은 것이다.
  AttendanceResult nextAttendance = const AttendanceResult(granted: false, amount: 0);

  /// 다음 출석이 이 오류로 실패한다.
  Object? nextAttendanceError;
  var attendanceCalls = 0;

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  FirebaseFunctions get functions => throw UnimplementedError();

  @override
  Stream<CoinWallet?> watchWallet(String uid) async* {
    if (_latest.containsKey(uid)) {
      yield _latest[uid];
    }
    yield* _getController(uid).stream;
  }

  @override
  Future<CoinWallet?> getWallet(String uid) async => _latest[uid];

  @override
  Future<AttendanceResult> claimAttendance() async {
    attendanceCalls++;
    final error = nextAttendanceError;
    if (error != null) {
      nextAttendanceError = null;
      throw error;
    }
    return nextAttendance;
  }

  /// 서버가 [uid]의 잔액을 [balance]로 바꾼 것처럼 보낸다.
  void emit(String uid, int balance) {
    final wallet = CoinWallet(
      freeCoins: balance,
      paidCoins: 0,
      balance: balance,
      attendanceDay: null,
      attendanceStreak: 0,
      updatedAt: DateTime.utc(2026, 11, 6),
    );
    _latest[uid] = wallet;
    _getController(uid).add(wallet);
  }

  StreamController<CoinWallet?> _getController(String uid) =>
      _controllers.putIfAbsent(uid, StreamController<CoinWallet?>.broadcast);
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

  @override
  Future<void> useTimeExtension(String gameId, {required int extensionIndex, required int coinCost}) =>
      _record('useTimeExtension $gameId $extensionIndex $coinCost');

  @override
  Future<void> useGamePractice(String gameId, {required int coinCost}) => _record('useGamePractice $gameId $coinCost');

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

  /// 쓴 것. 예: `create opp true`, `create opp true tabHidden false`, `foreground opp c1`, `background opp c1`,
  /// `tabHidden opp c1`, `tabVisible opp c1`, `lastSeenAt opp c1`.
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
  Future<String> createConnection(String uid, {required bool foreground, bool? tabHidden}) async {
    writes.add(tabHidden == null ? 'create $uid $foreground' : 'create $uid $foreground tabHidden $tabHidden');
    _createdCount++;
    return 'c$_createdCount';
  }

  @override
  Future<void> markForeground(String uid, String connectionId) async => writes.add('foreground $uid $connectionId');

  @override
  Future<void> markTabHidden(String uid, String connectionId) async => writes.add('tabHidden $uid $connectionId');

  @override
  Future<void> markTabVisible(String uid, String connectionId) async => writes.add('tabVisible $uid $connectionId');

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

  /// `challengesEnabled` 쓰기. 예: `me false`.
  final challengesEnabledWrites = <String>[];

  @override
  Future<void> updateChallengesEnabled(String uid, bool enabled) async => challengesEnabledWrites.add('$uid $enabled');

  @override
  Future<UserPrivate?> getUserPrivate(String uid) async => _latest[uid];

  /// 경고 지우기. 예: `me`.
  final clearWarningWrites = <String>[];

  @override
  Future<void> clearWarning(String uid) async => clearWarningWrites.add(uid);

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

/// 대국실 접속자 목록을 테스트가 직접 보내고, 내 항목 쓰기와 `enterLobby` 호출을 기록하는 가짜 OnlineUserRepository.
class FakeOnlineUserRepository implements OnlineUserRepository {
  final _usersController = StreamController<Map<String, OnlineUser>>.broadcast();
  final _entryControllers = <String, StreamController<OnlineUser?>>{};
  Map<String, OnlineUser>? _latestUsers;
  final _latestEntries = <String, OnlineUser?>{};

  /// 부른 것. 예: `onDisconnect me`, `enterLobby`, `remove me`, `challengesEnabled me false`.
  final calls = <String>[];

  /// `enterLobby`를 받으면 [enteringUid]의 항목으로 보낼 값. null이면 보내지 않는다(서버가 아직 쓰지 않았다).
  OnlineUser? entryOnEnter;

  /// `enterLobby`가 항목을 쓸 사용자.
  String? enteringUid;

  @override
  FirebaseDatabase get database => throw UnimplementedError();

  @override
  FirebaseFunctions get functions => throw UnimplementedError();

  @override
  Uri Function() get getServerUrl => throw UnimplementedError();

  @override
  Stream<Map<String, OnlineUser>> watchOnlineUsers() async* {
    final latest = _latestUsers;
    if (latest != null) {
      yield latest;
    }
    yield* _usersController.stream;
  }

  /// 접속자 목록이 바뀐 것처럼 보낸다.
  void emitUsers(Map<String, OnlineUser> users) {
    _latestUsers = users;
    _usersController.add(users);
  }

  @override
  Stream<OnlineUser?> watchOnlineUser(String uid) async* {
    if (_latestEntries.containsKey(uid)) {
      yield _latestEntries[uid];
    }
    yield* _getEntryController(uid).stream;
  }

  /// [uid]의 항목이 바뀐 것처럼 보낸다.
  void emitEntry(String uid, OnlineUser? entry) {
    _latestEntries[uid] = entry;
    _getEntryController(uid).add(entry);
  }

  @override
  Future<void> setRemoveOnDisconnect(String uid) async => calls.add('onDisconnect $uid');

  @override
  Future<void> enterLobby() async {
    calls.add('enterLobby');
    final uid = enteringUid;
    final entry = entryOnEnter;
    if (uid != null && entry != null) {
      emitEntry(uid, entry);
    }
  }

  @override
  Future<void> removeOnlineUser(String uid) async {
    calls.add('remove $uid');
    emitEntry(uid, null);
  }

  @override
  Future<void> updateChallengesEnabled(String uid, bool enabled) async => calls.add('challengesEnabled $uid $enabled');

  StreamController<OnlineUser?> _getEntryController(String uid) =>
      _entryControllers.putIfAbsent(uid, StreamController<OnlineUser?>.broadcast);
}

/// 대국 서버의 신청 API 호출을 기록하고, 테스트가 `challenges` 문서를 직접 보내는 가짜 ChallengeRepository.
class FakeChallengeRepository implements ChallengeRepository {
  final _controllers = <String, StreamController<Challenge?>>{};
  final _latest = <String, Challenge?>{};

  /// 부른 API와 파라미터. 예: `sendChallenge opp random null null`, `respondChallenge c1 true`.
  final calls = <String>[];

  /// 다음 대국 서버 호출이 이 오류로 실패한다.
  Object? nextError;

  /// 보낸 신청이 받을 ID.
  var sentChallengeId = 'challenge1';

  /// `respondChallenge`가 돌려줄 결과.
  ({String? gameId, String? roomId}) respondResult = (gameId: null, roomId: null);

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  FirebaseFunctions get functions => throw UnimplementedError();

  @override
  Uri Function() get getServerUrl => throw UnimplementedError();

  @override
  Stream<Challenge?> watchChallenge(String challengeId) async* {
    if (_latest.containsKey(challengeId)) {
      yield _latest[challengeId];
    }
    yield* _getController(challengeId).stream;
  }

  /// 대국 서버가 신청을 바꾼 것처럼 보낸다.
  void emit(String challengeId, Challenge? challenge) {
    _latest[challengeId] = challenge;
    _getController(challengeId).add(challenge);
  }

  @override
  Future<String> sendChallenge({
    required String toUid,
    required SideChoice? senderSide,
    required HandicapRemover? handicapRemover,
    required List<HandicapPiece>? handicapPieces,
  }) async {
    final pieces = handicapPieces?.map((piece) => piece.name).join(',');
    await _record('sendChallenge $toUid ${senderSide?.name} ${handicapRemover?.name} $pieces');
    return sentChallengeId;
  }

  @override
  Future<String> sendRoomInvite({required String toUid, required String roomId}) async {
    await _record('sendRoomInvite $toUid $roomId');
    return sentChallengeId;
  }

  @override
  Future<void> cancelChallenge(String challengeId) => _record('cancelChallenge $challengeId');

  @override
  Future<({String? gameId, String? roomId})> respondChallenge(String challengeId, {required bool accepted}) async {
    await _record('respondChallenge $challengeId $accepted');
    return respondResult;
  }

  Future<void> _record(String call) async {
    calls.add(call);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  StreamController<Challenge?> _getController(String challengeId) =>
      _controllers.putIfAbsent(challengeId, StreamController<Challenge?>.broadcast);
}

/// 차단 쓰기를 기록하고 내 차단 목록을 바로 보내는 가짜 UserBlockRepository.
class FakeUserBlockRepository implements UserBlockRepository {
  final _controllers = <String, StreamController<Set<String>>>{};
  final _blocked = <String, Set<String>>{};

  // 차단한 시각. `uid blockedUid`별이다.
  final _createdAt = <String, DateTime>{};

  /// 쓴 차단. 예: `me opp`.
  final writes = <String>[];

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  Stream<Set<String>> watchBlockedUids(String uid) async* {
    yield {...?_blocked[uid]};
    yield* _getController(uid).stream;
  }

  @override
  Future<void> createBlock(String uid, String blockedUid) async {
    writes.add('$uid $blockedUid');
    _createdAt['$uid $blockedUid'] = DateTime.utc(2026, 11, 3).add(Duration(minutes: _createdAt.length));
    final blocked = _blocked.putIfAbsent(uid, () => <String>{})..add(blockedUid);
    _getController(uid).add({...blocked});
  }

  @override
  Future<List<({String blockedUid, DateTime createdAt})>> getBlocks(String uid) async {
    final blocks = [
      for (final blockedUid in _blocked[uid] ?? const <String>{})
        (blockedUid: blockedUid, createdAt: _createdAt['$uid $blockedUid']!),
    ];
    blocks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return blocks;
  }

  @override
  Future<void> deleteBlock(String uid, String blockedUid) async {
    writes.add('delete $uid $blockedUid');
    final blocked = _blocked.putIfAbsent(uid, () => <String>{})..remove(blockedUid);
    _getController(uid).add({...blocked});
  }

  StreamController<Set<String>> _getController(String uid) =>
      _controllers.putIfAbsent(uid, StreamController<Set<String>>.broadcast);
}

class FakeSpectateListRepository implements SpectateListRepository {
  final _controllers = <String, StreamController<SpectateListEntry?>>{};
  final _latest = <String, SpectateListEntry?>{};

  /// [getEntries]가 돌려줄 목록. 정렬하지 않은 그대로다.
  var entries = <({String gameId, SpectateListEntry entry})>[];

  /// 다음 [getEntries]가 이 오류로 실패한다.
  Object? nextError;

  /// [getEntries]를 부른 횟수.
  var getEntriesCount = 0;

  @override
  FirebaseDatabase get database => throw UnimplementedError();

  @override
  Future<List<({String gameId, SpectateListEntry entry})>> getEntries() async {
    getEntriesCount++;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    return entries;
  }

  @override
  Stream<SpectateListEntry?> watchEntry(String gameId) async* {
    yield _latest[gameId];
    yield* _getController(gameId).stream;
  }

  void emit(String gameId, SpectateListEntry? entry) {
    _latest[gameId] = entry;
    _getController(gameId).add(entry);
  }

  StreamController<SpectateListEntry?> _getController(String gameId) =>
      _controllers.putIfAbsent(gameId, StreamController<SpectateListEntry?>.broadcast);
}

class FakeSpectatorRepository implements SpectatorRepository {
  /// 지금 남아 있는 관전자 표시. `gameId/viewerId`.
  final spectators = <String>{};

  /// 만들고 지운 기록. `create gameId`, `remove gameId`.
  final calls = <String>[];

  var _nextId = 0;

  @override
  FirebaseDatabase get database => throw UnimplementedError();

  @override
  String createViewerId() => 'viewer${_nextId++}'.padRight(20, '0');

  @override
  Future<void> createSpectator(String gameId, String viewerId) async {
    calls.add('create $gameId');
    spectators.add('$gameId/$viewerId');
  }

  @override
  Future<void> removeSpectator(String gameId, String viewerId) async {
    calls.add('remove $gameId');
    spectators.remove('$gameId/$viewerId');
  }
}

/// 채팅을 테스트가 직접 보내고, 보낸 메시지와 신고를 기록하는 가짜 ChatRepository.
class FakeChatRepository implements ChatRepository {
  final _controllers = <String, StreamController<List<ChatEntry>>>{};
  final _messages = <String, List<ChatEntry>>{};
  var _nextId = 0;

  /// 앱이 보낸 메시지와 신고. 예: `send game g1 안녕하세요`, `report lobby - m1`.
  final calls = <String>[];

  /// 다음 보내기·신고가 이 오류로 실패한다.
  Object? nextError;

  @override
  FirebaseDatabase get database => throw UnimplementedError();

  @override
  FirebaseFunctions get functions => throw UnimplementedError();

  @override
  Stream<List<ChatEntry>> watchMessages(ChatChannel channel, String? gameId) async* {
    final key = _getKey(channel, gameId);
    yield [...?_messages[key]];
    yield* _getController(key).stream;
  }

  @override
  Future<void> sendChatMessage(ChatChannel channel, String? gameId, String text) async {
    calls.add('send ${channel.name} ${gameId ?? '-'} $text');
    _throwNextError();
  }

  @override
  Future<void> reportMessage(ChatChannel channel, String? gameId, String messageId) async {
    calls.add('report ${channel.name} ${gameId ?? '-'} $messageId');
    _throwNextError();
  }

  /// 서버가 검사를 통과한 메시지를 쓴 것처럼 보낸다. 메시지 ID를 돌려준다.
  String addMessage(
    ChatChannel channel,
    String? gameId, {
    required String uid,
    required String nickname,
    required String text,
  }) {
    final key = _getKey(channel, gameId);
    final id = 'm${(_nextId++).toString().padLeft(4, '0')}';
    final messages = _messages.putIfAbsent(key, () => <ChatEntry>[])
      ..add((id: id, message: ChatMessage(uid: uid, nickname: nickname, text: text, sentAt: 1000 + _nextId)));
    _getController(key).add([...messages]);
    return id;
  }

  void _throwNextError() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  static String _getKey(ChatChannel channel, String? gameId) => '${channel.name} ${gameId ?? '-'}';

  StreamController<List<ChatEntry>> _getController(String key) =>
      _controllers.putIfAbsent(key, StreamController<List<ChatEntry>>.broadcast);
}

class FakeArchivedGameRepository implements ArchivedGameRepository {
  /// 끝난 대국. 최근에 끝난 것이 앞이다.
  var games = <({String gameId, ArchivedGame game})>[];

  /// 다음 읽기가 이 오류로 실패한다.
  Object? nextError;

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  Future<List<({String gameId, ArchivedGame game})>> getArchivedGames(
    String uid, {
    required int limit,
    DateTime? endedBefore,
    DateTime? endedSince,
  }) async {
    _throwNextError();
    return games
        .where((item) => item.game.playerUids.contains(uid))
        .where((item) => endedBefore == null || item.game.endedAt.isBefore(endedBefore))
        .where((item) => endedSince == null || !item.game.endedAt.isBefore(endedSince))
        .take(limit)
        .toList();
  }

  @override
  Future<({int games, int wins})> getPairRecord(String uid, String opponentUid) async {
    _throwNextError();
    final pairGames = [
      for (final item in games)
        if (item.game.playerUids.contains(uid) && item.game.playerUids.contains(opponentUid)) item.game,
    ];
    return (
      games: pairGames.length,
      wins: pairGames.where((game) => game.players.get(game.result.winner).uid == uid).length,
    );
  }

  void _throwNextError() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }
}

/// 기기 저장소 없이 언어 설정을 기억하는 가짜 DeviceSettingsRepository.
class FakeDeviceSettingsRepository implements DeviceSettingsRepository {
  var language = AppLanguage.system;
  var soundEnabled = true;
  var vibrationEnabled = true;

  @override
  SharedPreferencesAsync get preferences => throw UnimplementedError();

  @override
  Future<bool> getSoundEnabled() async => soundEnabled;

  @override
  Future<void> updateSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
  }

  @override
  Future<bool> getVibrationEnabled() async => vibrationEnabled;

  @override
  Future<void> updateVibrationEnabled(bool enabled) async {
    vibrationEnabled = enabled;
  }

  @override
  Future<AppLanguage> getLanguage() async => language;

  @override
  Future<void> updateLanguage(AppLanguage language) async {
    this.language = language;
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
  FakeConfigRepository configs,
  FakeOnlineUserRepository onlineUsers,
  FakeChallengeRepository challenges,
  FakeUserBlockRepository blocks,
  FakeSpectateListRepository spectateList,
  FakeSpectatorRepository spectators,
  FakeChatRepository chats,
  FakeArchivedGameRepository archivedGames,
  FakeDeviceSettingsRepository deviceSettings,
  FakeCoinWalletRepository coinWallets,
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
  final configRepository = FakeConfigRepository();
  final onlineUserRepository = FakeOnlineUserRepository();
  final challengeRepository = FakeChallengeRepository();
  final userBlockRepository = FakeUserBlockRepository();
  final spectateListRepository = FakeSpectateListRepository();
  final spectatorRepository = FakeSpectatorRepository();
  final chatRepository = FakeChatRepository();
  final archivedGameRepository = FakeArchivedGameRepository();
  final deviceSettingsRepository = FakeDeviceSettingsRepository();
  final coinWalletRepository = FakeCoinWalletRepository();
  repositories = AppRepositories(
    authRepository: authRepository,
    configRepository: configRepository,
    userRepository: userRepository,
    userPrivateRepository: userPrivateRepository,
    playerStateRepository: playerStateRepository,
    gameRepository: gameRepository,
    serverTimeRepository: FakeServerTimeRepository(),
    connectionRepository: connectionRepository,
    roomRepository: roomRepository,
    deepLinkRepository: deepLinkRepository,
    onlineUserRepository: onlineUserRepository,
    challengeRepository: challengeRepository,
    userBlockRepository: userBlockRepository,
    spectateListRepository: spectateListRepository,
    spectatorRepository: spectatorRepository,
    chatRepository: chatRepository,
    archivedGameRepository: archivedGameRepository,
    deviceSettingsRepository: deviceSettingsRepository,
    coinWalletRepository: coinWalletRepository,
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
    configs: configRepository,
    onlineUsers: onlineUserRepository,
    challenges: challengeRepository,
    blocks: userBlockRepository,
    spectateList: spectateListRepository,
    spectators: spectatorRepository,
    chats: chatRepository,
    archivedGames: archivedGameRepository,
    deviceSettings: deviceSettingsRepository,
    coinWallets: coinWalletRepository,
  );
}
