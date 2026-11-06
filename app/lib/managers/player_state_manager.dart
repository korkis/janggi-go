import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/player_state.dart';
import '../repositories/app_repositories.dart';
import '../utils/app_exception.dart';
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

  /// 방, 빠른 대국 대기열, 대국 신청에서 나온다. 회원 탈퇴 전에 부른다(`docs/database.md`의 회원 탈퇴). 방장이면 방이 닫힌다.
  Future<void> leaveMatching() async {
    final state = _playerState;
    if (state == null) {
      return;
    }
    final roomId = state.roomId;
    if (roomId != null) {
      await repositories.roomRepository.leaveRoom(roomId);
    }
    if (state.quickQueueJoinedAt != null) {
      await repositories.gameRepository.leaveQuickQueue();
    }
    final outgoingChallengeId = state.outgoingChallengeId;
    if (outgoingChallengeId != null) {
      await repositories.challengeRepository.cancelChallenge(outgoingChallengeId);
    }
    final incomingChallengeId = state.incomingChallengeId;
    if (incomingChallengeId != null) {
      await _declineChallenge(incomingChallengeId);
    }
  }

  /// 받은 신청을 거절한다. 그새 끝났으면 그대로 둔다.
  Future<void> _declineChallenge(String challengeId) async {
    try {
      await repositories.challengeRepository.respondChallenge(challengeId, accepted: false);
    } on AppException catch (error) {
      if (error.code != AppErrorCode.gameNotFound) {
        rethrow;
      }
    }
  }

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
