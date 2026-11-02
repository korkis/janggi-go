import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../repositories/app_repositories.dart';
import '../utils/invite_link.dart';

/// 초대 링크로 들어온 방(`docs/game/matching.md`의 링크). 앱 수명 동안 하나다.
///
/// 앱을 연 링크, 앱이 켜져 있는 동안 누른 링크, 안드로이드에서 링크로 설치한 뒤 처음 켠 때의 설치 정보를 받아 들어갈 방을
/// [pendingRoomId]에 둔다. 홈 화면이 이 값을 가져가 로그인과 닉네임을 거친 뒤 방에 들어간다.
class InviteLinkManager extends ChangeNotifier {
  StreamSubscription<Uri>? _subscription;

  // 들어갈 방. 홈 화면이 가져가면 null이다.
  String? _pendingRoomId;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// 아직 들어가지 않은 초대 링크의 방.
  String? get pendingRoomId => _pendingRoomId;

  /// 링크와 설치 정보를 받기 시작한다. 앱을 켤 때 한 번 부른다.
  void start() {
    _subscription ??= repositories.deepLinkRepository.watchLinks().listen(_onLink, onError: _onLinkError);
    _readInstallReferrer();
  }

  /// 들어갈 방을 가져가고 비운다. 없으면 null.
  String? takePendingRoomId() {
    final roomId = _pendingRoomId;
    _pendingRoomId = null;
    return roomId;
  }

  void _onLink(Uri uri) {
    final roomId = getInviteRoomId(uri);
    if (roomId == null) {
      return;
    }
    _setPendingRoomId(roomId);
  }

  void _onLinkError(Object error, StackTrace stackTrace) {
    developer.log('InviteLinkManager 링크 받기 실패', error: error, stackTrace: stackTrace);
  }

  Future<void> _readInstallReferrer() async {
    try {
      final referrer = await repositories.deepLinkRepository.takeInstallReferrer();
      final roomId = referrer == null ? null : getInstallReferrerRoomId(referrer);
      // 앱을 연 링크가 먼저 왔으면 그 방을 따른다.
      if (roomId != null && _pendingRoomId == null) {
        _setPendingRoomId(roomId);
      }
    } catch (error, stackTrace) {
      developer.log('DeepLinkRepository.takeInstallReferrer 실패', error: error, stackTrace: stackTrace);
    }
  }

  void _setPendingRoomId(String roomId) {
    _pendingRoomId = roomId;
    notifyListeners();
  }
}
