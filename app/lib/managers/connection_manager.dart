import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import '../models/connection.dart';
import '../repositories/app_repositories.dart';
import 'auth_manager.dart';
import 'player_state_manager.dart';

/// 내 접속 상태. 로그인한 동안 RTDB `connections/{uid}`에 연결 하나를 유지한다(`docs/server.md`의 접속 끊김).
///
/// - RTDB에 연결될 때마다 연결을 새로 만들고 `onDisconnect`로 `online: false`를 걸어 둔다.
/// - 다른 앱으로 넘어가면 `foreground: false`, 돌아오면 `foreground: true`와 `activeSince`를 쓴다.
/// - 진행 중 대국(`player_states.gameId`)이 있는 동안 `configs/app.heartbeatSeconds`마다 `lastSeenAt`을 갱신한다.
/// - 대국 중에 다시 연결되거나 화면에 돌아오면 `checkGame`을 불러 서버가 끊긴 시간을 바로 정리하게 한다.
/// - 로그인한 동안 내 `connections/{uid}`를 들어 RTDB 연결을 유지한다. 안드로이드 RTDB SDK는 서버에서 듣는 경로가 없으면
///   60초 뒤 연결을 닫으므로, 그대로 두면 홈, 빠른 대국 대기, 방 대기실처럼 Firestore만 듣는 화면에서 끊긴 것으로 보인다.
class ConnectionManager extends ChangeNotifier {
  final AuthManager authManager;
  final PlayerStateManager playerStateManager;

  StreamSubscription<bool>? _connectedSubscription;

  // RTDB 연결을 유지하려고 듣는 내 `connections/{uid}`. 받은 값은 쓰지 않는다.
  StreamSubscription<List<Connection>>? _keepAliveSubscription;
  AppLifecycleListener? _lifecycleListener;
  Timer? _heartbeatTimer;

  bool _connected = false;
  bool _foreground = true;

  // 연결을 쓰고 있는 사용자.
  String? _uid;

  // 지금 연결의 키. RTDB에 연결되어 있고 연결을 만든 뒤에만 있다.
  String? _connectionId;

  // 연결을 만들 때마다 1씩 는다. 늦게 끝난 이전 연결 만들기의 결과를 버리기 위해서다.
  var _connectionVersion = 0;

  // `lastSeenAt`을 갱신하는 대국.
  String? _gameId;

  // `configs/app.heartbeatSeconds`. 처음 필요할 때 읽는다.
  Duration? _heartbeatInterval;
  bool _heartbeatIntervalLoading = false;

  ConnectionManager({required this.authManager, required this.playerStateManager}) {
    _uid = authManager.uid;
    _gameId = playerStateManager.gameId;
    authManager.addListener(_onAuthChanged);
    playerStateManager.addListener(_onPlayerStateChanged);
    _connectedSubscription = repositories.connectionRepository.watchConnected().listen(
      _onConnectedChanged,
      onError: _onConnectedError,
    );
    _syncKeepAlive();
  }

  @override
  void dispose() {
    authManager.removeListener(_onAuthChanged);
    playerStateManager.removeListener(_onPlayerStateChanged);
    _connectedSubscription?.cancel();
    _keepAliveSubscription?.cancel();
    _lifecycleListener?.dispose();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  /// 이 기기가 RTDB 서버에 연결되어 있는지. 끊기면 대국 화면이 "다시 연결하는 중"을 보여준다.
  bool get connected => _connected;

  /// 앱이 화면에 떠 있는지.
  bool get foreground => _foreground;

  /// 서버가 연결된 것으로 볼 상태를 쓰고 있는지. 연결을 만들었고 앱이 화면에 떠 있다.
  bool get active => _connectionId != null && _foreground;

  /// 앱이 화면에 떠 있는지 듣기 시작한다. `main()`이 한 번 부른다.
  void observeAppLifecycle() {
    _lifecycleListener ??= AppLifecycleListener(onStateChange: _onAppLifecycleChanged);
  }

  /// 앱은 연결되어 있는데 서버가 나를 끊긴 것으로 기록했을 때 `activeSince`를 새로 쓴다. 네트워크가 잠깐 멈췄다 이어져
  /// RTDB 연결이 바뀌지 않은 경우다. 서버는 끊긴 뒤에 쓴 `activeSince`가 있어야 돌아온 것으로 센다.
  Future<void> renewActiveSince() async {
    final uid = _uid;
    final connectionId = _connectionId;
    if (uid == null || connectionId == null || !_foreground) {
      return;
    }
    await repositories.connectionRepository.markForeground(uid, connectionId);
  }

  void _onConnectedChanged(bool connected) {
    if (connected == _connected) {
      return;
    }
    _connected = connected;
    if (!connected) {
      _connectionId = null;
      _connectionVersion++;
    }
    _syncHeartbeat();
    notifyListeners();
    if (connected) {
      _openConnection();
    }
  }

  void _onConnectedError(Object error, StackTrace stackTrace) {
    developer.log('ConnectionManager .info/connected 듣기 실패', error: error, stackTrace: stackTrace);
  }

  void _onAuthChanged() {
    final uid = authManager.uid;
    if (uid == _uid) {
      return;
    }
    _uid = uid;
    _connectionId = null;
    _connectionVersion++;
    _syncKeepAlive();
    _syncHeartbeat();
    notifyListeners();
    if (uid != null && _connected) {
      _openConnection();
    }
  }

  /// 로그인한 사용자의 `connections/{uid}`를 듣는다. 로그아웃하면 그만 듣는다.
  void _syncKeepAlive() {
    _keepAliveSubscription?.cancel();
    _keepAliveSubscription = null;
    final uid = _uid;
    if (uid == null) {
      return;
    }
    _keepAliveSubscription = repositories.connectionRepository
        .watchConnections(uid)
        .listen(_onOwnConnectionsChanged, onError: _onOwnConnectionsError);
  }

  /// 연결을 유지하려고 듣는 것이라 받은 값은 쓰지 않는다.
  void _onOwnConnectionsChanged(List<Connection> connections) {}

  void _onOwnConnectionsError(Object error, StackTrace stackTrace) {
    developer.log('ConnectionManager connections 듣기 실패', error: error, stackTrace: stackTrace);
  }

  void _onPlayerStateChanged() {
    final gameId = playerStateManager.gameId;
    if (gameId == _gameId) {
      return;
    }
    _gameId = gameId;
    _syncHeartbeat();
  }

  /// 화면에 보이면(`resumed`, `inactive`) 떠 있는 것으로 보고, 숨겨지면(`hidden`, `paused`, `detached`) 넘어간 것으로 본다.
  void _onAppLifecycleChanged(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    if (foreground == _foreground) {
      return;
    }
    _foreground = foreground;
    _writeForeground(foreground);
    _syncHeartbeat();
    notifyListeners();
  }

  Future<void> _writeForeground(bool foreground) async {
    final uid = _uid;
    final connectionId = _connectionId;
    if (uid == null || connectionId == null) {
      return;
    }
    try {
      if (foreground) {
        await repositories.connectionRepository.markForeground(uid, connectionId);
      } else {
        await repositories.connectionRepository.markBackground(uid, connectionId);
      }
    } catch (error, stackTrace) {
      developer.log('ConnectionManager foreground 쓰기 실패', error: error, stackTrace: stackTrace);
      return;
    }
    if (foreground) {
      await _checkGame();
    }
  }

  Future<void> _openConnection() async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    final version = ++_connectionVersion;
    final String connectionId;
    try {
      connectionId = await repositories.connectionRepository.createConnection(uid, foreground: _foreground);
    } catch (error, stackTrace) {
      developer.log('ConnectionRepository.createConnection 실패', error: error, stackTrace: stackTrace);
      return;
    }
    if (version != _connectionVersion) {
      return;
    }
    _connectionId = connectionId;
    _syncHeartbeat();
    notifyListeners();
    await _checkGame();
  }

  /// 진행 중 대국이 있으면 판정을 다시 보게 한다. 실패해도 상대 앱이나 예약 작업이 다시 판정하므로 로그만 남긴다.
  Future<void> _checkGame() async {
    final gameId = _gameId;
    if (gameId == null) {
      return;
    }
    try {
      await repositories.gameRepository.checkGame(gameId);
    } catch (error, stackTrace) {
      developer.log('GameRepository.checkGame 실패', error: error, stackTrace: stackTrace);
    }
  }

  /// 연결이 있고, 화면에 떠 있고, 진행 중 대국이 있는 동안만 `lastSeenAt`을 갱신한다. 시작할 때 한 번 바로 쓴다.
  void _syncHeartbeat() {
    if (_connectionId == null || !_foreground || _gameId == null) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      return;
    }
    final interval = _heartbeatInterval;
    if (interval == null) {
      _loadHeartbeatInterval();
      return;
    }
    if (_heartbeatTimer != null) {
      return;
    }
    _heartbeatTimer = Timer.periodic(interval, _onHeartbeat);
    _writeLastSeenAt();
  }

  Future<void> _loadHeartbeatInterval() async {
    if (_heartbeatIntervalLoading) {
      return;
    }
    try {
      _heartbeatIntervalLoading = true;
      final config = await repositories.configRepository.getAppConfig();
      _heartbeatInterval = Duration(seconds: config.heartbeatSeconds);
    } catch (error, stackTrace) {
      // 다음에 연결, 화면, 대국이 바뀔 때 다시 읽는다.
      developer.log('ConfigRepository.getAppConfig 실패', error: error, stackTrace: stackTrace);
      return;
    } finally {
      _heartbeatIntervalLoading = false;
    }
    _syncHeartbeat();
  }

  void _onHeartbeat(Timer timer) {
    _writeLastSeenAt();
  }

  Future<void> _writeLastSeenAt() async {
    final uid = _uid;
    final connectionId = _connectionId;
    if (uid == null || connectionId == null) {
      return;
    }
    try {
      await repositories.connectionRepository.updateLastSeenAt(uid, connectionId);
    } catch (error, stackTrace) {
      developer.log('ConnectionRepository.updateLastSeenAt 실패', error: error, stackTrace: stackTrace);
    }
  }
}
