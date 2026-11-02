import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/player_state.dart';
import '../repositories/app_repositories.dart';
import 'auth_manager.dart';

/// 내 `player_states` 문서. 로그인한 동안 듣는다(`docs/server.md`의 앱과 서버의 흐름).
///
/// 대국 서버가 대국을 만들면 `gameId`가 생기고, 화면은 이 값을 보고 대국으로 옮겨 간다.
class PlayerStateManager extends ChangeNotifier {
  final AuthManager authManager;

  StreamSubscription<PlayerState?>? _subscription;

  // 지금 듣고 있는 사용자.
  String? _uid;
  PlayerState? _playerState;

  PlayerStateManager({required this.authManager}) {
    authManager.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    authManager.removeListener(_onAuthChanged);
    _subscription?.cancel();
    super.dispose();
  }

  /// 내 상태. 로그인하지 않았거나 아직 문서가 없으면 null이다.
  PlayerState? get playerState => _playerState;

  /// 진행 중(상차림 포함) 대국.
  String? get gameId => _playerState?.gameId;

  void _onAuthChanged() {
    final uid = authManager.uid;
    if (uid == _uid) {
      return;
    }
    _uid = uid;
    _subscription?.cancel();
    _subscription = null;
    _playerState = null;
    if (uid != null) {
      _subscription = repositories.playerStateRepository
          .watchPlayerState(uid)
          .listen(_onPlayerStateChanged, onError: _onPlayerStateError);
    }
    notifyListeners();
  }

  void _onPlayerStateChanged(PlayerState? playerState) {
    _playerState = playerState;
    notifyListeners();
  }

  void _onPlayerStateError(Object error, StackTrace stackTrace) {
    developer.log('PlayerStateManager 듣기 실패', error: error, stackTrace: stackTrace);
  }
}
