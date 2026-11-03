import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/user_private.dart';
import '../models/user_profile.dart';
import '../repositories/app_repositories.dart';
import 'auth_manager.dart';

/// 내 급수와 다음 급수까지의 진행(`docs/game/rank.md`의 화면 표시). 로그인한 동안 듣는다.
///
/// 급수(`users.rankLevel`)와 진행(`users_private.rankProgress`, `winsToNextRank`)은 급수 대국이 끝날 때 대국 서버가 바꾸므로
/// 한 번 읽어 두는 [AuthManager.profile]과 따로 듣는다.
class RankManager extends ChangeNotifier {
  final AuthManager authManager;

  StreamSubscription<UserProfile?>? _profileSubscription;
  StreamSubscription<UserPrivate?>? _privateSubscription;

  // 지금 듣고 있는 사용자.
  String? _uid;
  UserProfile? _profile;
  UserPrivate? _private;

  RankManager({required this.authManager}) {
    authManager.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    authManager.removeListener(_onAuthChanged);
    _profileSubscription?.cancel();
    _privateSubscription?.cancel();
    super.dispose();
  }

  /// 급수. 1이 18급, 27이 9단이다. 아직 읽지 못했으면 [AuthManager.profile]의 값을 쓰고, 로그인하지 않았으면 null.
  int? get rankLevel => _profile?.rankLevel ?? authManager.profile?.rankLevel;

  /// 지금 급수 구간 안에서의 위치 0~1. 아직 읽지 못했으면 null.
  double? get rankProgress => _private?.rankProgress;

  /// 다음 급수까지의 어림 승수. 9단이거나 아직 급수 대국을 두지 않았으면 null.
  int? get winsToNextRank => _private?.winsToNextRank;

  /// 전적의 대국 수(`users.stats.games`). 대국이 끝날 때마다 늘어서 홈의 최근 내 대국이 새 기보를 다시 읽는 데 쓴다.
  /// 아직 읽지 못했으면 null.
  int? get gameCount => _profile?.stats.games;

  void _onAuthChanged() {
    final uid = authManager.uid;
    if (uid == _uid) {
      return;
    }
    _uid = uid;
    _profileSubscription?.cancel();
    _privateSubscription?.cancel();
    _profileSubscription = null;
    _privateSubscription = null;
    _profile = null;
    _private = null;
    if (uid != null) {
      _profileSubscription = repositories.userRepository
          .watchUser(uid)
          .listen(_onProfileChanged, onError: _onWatchError);
      _privateSubscription = repositories.userPrivateRepository
          .watchUserPrivate(uid)
          .listen(_onPrivateChanged, onError: _onWatchError);
    }
    notifyListeners();
  }

  void _onProfileChanged(UserProfile? profile) {
    _profile = profile;
    notifyListeners();
  }

  void _onPrivateChanged(UserPrivate? private) {
    _private = private;
    notifyListeners();
  }

  void _onWatchError(Object error, StackTrace stackTrace) {
    developer.log('RankManager 듣기 실패', error: error, stackTrace: stackTrace);
  }
}
