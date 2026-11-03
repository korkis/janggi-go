import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/user_private.dart';
import '../repositories/app_repositories.dart';
import 'auth_manager.dart';

/// 내게 지금 걸린 제재(`users_private.sanction`). 로그인한 동안 듣는다. Admin 웹에서 제재를 걸거나 예약 작업이 끝난 제재를
/// 지우면 바로 바뀐다(`docs/moderation.md`의 제재 단계와 안내).
class SanctionManager extends ChangeNotifier {
  final AuthManager authManager;

  StreamSubscription<UserPrivate?>? _subscription;

  // 지금 듣고 있는 사용자.
  String? _uid;
  ActiveSanction? _sanction;

  SanctionManager({required this.authManager}) {
    authManager.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    authManager.removeListener(_onAuthChanged);
    _subscription?.cancel();
    super.dispose();
  }

  /// 지금 알려야 할 제재. 경고는 확인해서 지우기 전까지, 기간이 있는 제재는 끝나기 전까지다. 끝난 제재는 예약 작업이 지우기 전이어도
  /// null이다. 로그인하지 않았거나 제재가 없으면 null.
  ActiveSanction? get sanction {
    final sanction = _sanction;
    final endsAt = sanction?.endsAt;
    if (sanction == null || (endsAt != null && !endsAt.isAfter(DateTime.now()))) {
      return null;
    }
    return sanction;
  }

  void _onAuthChanged() {
    final uid = authManager.uid;
    if (uid == _uid) {
      return;
    }
    _uid = uid;
    _subscription?.cancel();
    _subscription = null;
    _sanction = null;
    if (uid != null) {
      _subscription = repositories.userPrivateRepository
          .watchUserPrivate(uid)
          .listen(_onPrivateChanged, onError: _onWatchError);
    }
    notifyListeners();
  }

  void _onPrivateChanged(UserPrivate? private) {
    _sanction = private?.sanction;
    notifyListeners();
  }

  void _onWatchError(Object error, StackTrace stackTrace) {
    developer.log('SanctionManager 듣기 실패', error: error, stackTrace: stackTrace);
  }
}
