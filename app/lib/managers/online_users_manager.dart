import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/online_user.dart';
import '../repositories/app_repositories.dart';

/// 대국실 접속자 목록(`docs/screens.md`의 대국실). 접속자 탭과 방 대기실의 접속자 초대하기가 열려 있는 동안 듣는다.
///
/// 앱 수명 동안 쓰지 않으므로 `managers`에 두지 않고 화면이 만들고 `dispose()`한다.
class OnlineUsersManager extends ChangeNotifier {
  StreamSubscription<Map<String, OnlineUser>>? _subscription;

  Map<String, OnlineUser>? _users;
  var _failed = false;

  OnlineUsersManager() {
    _subscription = repositories.onlineUserRepository.watchOnlineUsers().listen(_onUsersChanged, onError: _onError);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// uid별 접속자. 아직 읽지 못했으면 null이다.
  Map<String, OnlineUser>? get users => _users;

  /// 목록을 읽지 못했다.
  bool get failed => _failed;

  void _onUsersChanged(Map<String, OnlineUser> users) {
    _users = users;
    _failed = false;
    notifyListeners();
  }

  void _onError(Object error, StackTrace stackTrace) {
    developer.log('OnlineUsersManager online_users 듣기 실패', error: error, stackTrace: stackTrace);
    _failed = true;
    notifyListeners();
  }
}
