import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../repositories/app_repositories.dart';
import 'auth_manager.dart';

/// 내가 차단한 사람들(`users/{uid}/blocks`). 로그인한 동안 듣는다.
///
/// 대국실 접속자 목록에서 차단한 사람을 숨긴다. 차단한 사람의 신청은 대국 서버가 전달하지 않는다. 채팅 숨기기(구현 순서 11번)도
/// 이 목록을 쓴다.
class BlockManager extends ChangeNotifier {
  final AuthManager authManager;

  StreamSubscription<Set<String>>? _subscription;

  // 지금 듣고 있는 사용자.
  String? _uid;
  Set<String> _blockedUids = const {};

  BlockManager({required this.authManager}) {
    authManager.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    authManager.removeListener(_onAuthChanged);
    _subscription?.cancel();
    super.dispose();
  }

  /// 내가 차단한 사람들의 uid. 로그인하지 않았거나 아직 읽지 못했으면 비어 있다.
  Set<String> get blockedUids => _blockedUids;

  bool isBlocked(String uid) => _blockedUids.contains(uid);

  void _onAuthChanged() {
    final uid = authManager.uid;
    if (uid == _uid) {
      return;
    }
    _uid = uid;
    _subscription?.cancel();
    _subscription = null;
    _blockedUids = const {};
    if (uid != null) {
      _subscription = repositories.userBlockRepository
          .watchBlockedUids(uid)
          .listen(_onBlocksChanged, onError: _onBlocksError);
    }
    notifyListeners();
  }

  void _onBlocksChanged(Set<String> blockedUids) {
    _blockedUids = blockedUids;
    notifyListeners();
  }

  void _onBlocksError(Object error, StackTrace stackTrace) {
    developer.log('BlockManager blocks 듣기 실패', error: error, stackTrace: stackTrace);
  }
}
