import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/challenge.dart';
import '../models/game_enums.dart';
import '../repositories/app_repositories.dart';
import 'player_state_manager.dart';

/// 내가 받고 아직 응답하지 않은 대국 신청(`docs/server.md`의 신청). 앱의 어느 화면에서든 수락 팝업을 띄우는 데 쓴다.
///
/// 대국 서버가 `player_states.incomingChallengeId`를 쓰면 그 `challenges` 문서를 듣는다. 응답하거나 마감되면 서버가 표시를
/// 지우므로 [incoming]도 null이 된다.
class ChallengeManager extends ChangeNotifier {
  final PlayerStateManager playerStateManager;

  StreamSubscription<Challenge?>? _subscription;

  // 지금 듣고 있는 신청.
  String? _challengeId;
  Challenge? _challenge;

  ChallengeManager({required this.playerStateManager}) {
    playerStateManager.addListener(_onPlayerStateChanged);
    _onPlayerStateChanged();
  }

  @override
  void dispose() {
    playerStateManager.removeListener(_onPlayerStateChanged);
    _subscription?.cancel();
    super.dispose();
  }

  /// 응답을 기다리는 받은 신청. 없거나 아직 읽지 못했으면 null이다.
  ({String id, Challenge challenge})? get incoming {
    final challengeId = _challengeId;
    final challenge = _challenge;
    if (challengeId == null || challenge == null || challenge.status != ChallengeStatus.pending) {
      return null;
    }
    return (id: challengeId, challenge: challenge);
  }

  void _onPlayerStateChanged() {
    final challengeId = playerStateManager.playerState?.incomingChallengeId;
    if (challengeId == _challengeId) {
      return;
    }
    _challengeId = challengeId;
    _challenge = null;
    _subscription?.cancel();
    _subscription = null;
    if (challengeId != null) {
      _subscription = repositories.challengeRepository
          .watchChallenge(challengeId)
          .listen(_onChallengeChanged, onError: _onChallengeError);
    }
    notifyListeners();
  }

  void _onChallengeChanged(Challenge? challenge) {
    _challenge = challenge;
    notifyListeners();
  }

  void _onChallengeError(Object error, StackTrace stackTrace) {
    developer.log('ChallengeManager challenges 듣기 실패', error: error, stackTrace: stackTrace);
  }
}
