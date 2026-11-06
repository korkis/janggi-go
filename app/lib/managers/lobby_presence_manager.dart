import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/online_user.dart';
import '../repositories/app_repositories.dart';
import 'auth_manager.dart';
import 'connection_manager.dart';

/// 대국실 접속자 목록의 내 항목(`docs/server.md`의 접속자 목록). 닉네임을 정하고 로그인한 동안 유지한다.
///
/// - RTDB에 연결되어 있고 앱이 화면에 떠 있으면 `onDisconnect`로 항목 삭제를 걸어 둔 뒤 `enterLobby`를 부른다.
/// - 다른 앱으로 넘어가면 항목을 지우고, 돌아오면 다시 `enterLobby`를 부른다.
/// - 지난 연결의 `onDisconnect`가 늦게 실행돼 항목이 지워지면 다시 `enterLobby`를 부른다.
///
/// `configs/app.onlineUsersVisible`이 꺼져 있어도 항목은 쓴다. 다른 사용자 정보의 상태와 신청 조건에 쓰기 때문이다.
class LobbyPresenceManager extends ChangeNotifier {
  final AuthManager authManager;
  final ConnectionManager connectionManager;

  StreamSubscription<OnlineUser?>? _entrySubscription;

  // 항목을 듣고 쓰는 사용자. 닉네임을 정하기 전이면 null이다.
  String? _uid;
  OnlineUser? _entry;

  // 대국실에 있어야 한다. 로그인과 닉네임, RTDB 연결, 화면에 떠 있음이 모두 맞다.
  var _present = false;
  var _entering = false;

  // 마지막으로 들어간 뒤 내 항목을 본 적이 있다. 그 뒤 없어지면 다시 들어간다. 들어가기가 실패해 항목이 생기지 않았으면
  // 다시 부르지 않아 같은 실패를 되풀이하지 않는다.
  var _seenEntry = false;

  LobbyPresenceManager({required this.authManager, required this.connectionManager}) {
    authManager.addListener(_sync);
    connectionManager.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    authManager.removeListener(_sync);
    connectionManager.removeListener(_sync);
    _entrySubscription?.cancel();
    super.dispose();
  }

  /// 대국실의 내 항목. 아직 들어가지 않았으면 null이다.
  OnlineUser? get entry => _entry;

  /// 대국 신청 받기를 바꾼다. 설정(`users_private`)에 쓰고, 대국실에 들어가 있으면 내 항목도 바꾼다.
  Future<void> setChallengesEnabled(bool enabled) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    await repositories.userPrivateRepository.updateChallengesEnabled(uid, enabled);
    if (_entry != null) {
      await repositories.onlineUserRepository.updateChallengesEnabled(uid, enabled);
    }
  }

  /// 로그아웃하기 전에 내 항목을 지운다. 로그아웃한 뒤에는 보안 규칙이 막아 지울 수 없고, RTDB 연결은 그대로라 `onDisconnect`도
  /// 실행되지 않으므로 다른 사람에게 계속 보인다.
  Future<void> leaveBeforeSignOut() async {
    final uid = _uid;
    // 다시 들어가지 않게 먼저 끈다. 로그아웃에 실패하면 다음 [_sync]가 다시 들어간다.
    _present = false;
    if (uid != null && connectionManager.connected) {
      await _leave(uid);
    }
  }

  void _sync() {
    final uid = authManager.profile == null ? null : authManager.uid;
    if (uid != _uid) {
      _uid = uid;
      _entry = null;
      _seenEntry = false;
      _present = false;
      _entrySubscription?.cancel();
      _entrySubscription = null;
      if (uid != null) {
        _entrySubscription = repositories.onlineUserRepository
            .watchOnlineUser(uid)
            .listen(_onEntryChanged, onError: _onEntryError);
      }
      notifyListeners();
    }
    final present = uid != null && connectionManager.connected && connectionManager.foreground;
    if (present == _present) {
      return;
    }
    _present = present;
    if (present) {
      _enter();
    } else if (uid != null && connectionManager.connected) {
      // 연결은 그대로이고 다른 앱으로 넘어갔다. 연결이 끊긴 경우는 걸어 둔 `onDisconnect`가 지운다.
      _leave(uid);
    }
  }

  void _onEntryChanged(OnlineUser? entry) {
    _entry = entry;
    if (entry != null) {
      _seenEntry = true;
    }
    notifyListeners();
    _reenterIfMissing();
  }

  void _onEntryError(Object error, StackTrace stackTrace) {
    developer.log('LobbyPresenceManager online_users 듣기 실패', error: error, stackTrace: stackTrace);
  }

  void _reenterIfMissing() {
    if (_present && !_entering && _seenEntry && _entry == null) {
      _enter();
    }
  }

  Future<void> _enter() async {
    final uid = _uid;
    if (uid == null || _entering) {
      return;
    }
    try {
      _entering = true;
      _seenEntry = false;
      await repositories.onlineUserRepository.setRemoveOnDisconnect(uid);
      await repositories.onlineUserRepository.enterLobby();
    } catch (error, stackTrace) {
      // 다음에 연결되거나 화면에 돌아올 때 다시 들어간다.
      developer.log('OnlineUserRepository.enterLobby 실패', error: error, stackTrace: stackTrace);
    } finally {
      _entering = false;
    }
    if (uid != _uid) {
      return;
    }
    if (!_present) {
      // 들어가는 사이 다른 앱으로 넘어갔다.
      if (connectionManager.connected) {
        await _leave(uid);
      }
      return;
    }
    _reenterIfMissing();
  }

  Future<void> _leave(String uid) async {
    try {
      await repositories.onlineUserRepository.removeOnlineUser(uid);
    } catch (error, stackTrace) {
      developer.log('OnlineUserRepository.removeOnlineUser 실패', error: error, stackTrace: stackTrace);
    }
  }
}
