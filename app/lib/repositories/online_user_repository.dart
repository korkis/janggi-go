import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/online_user.dart';
import 'game_repository.dart';
import 'game_server_call.dart';

/// RTDB `online_users`와 대국 서버의 `enterLobby`(`docs/server.md`의 접속자 목록).
///
/// 항목은 대국 서버가 쓰고, 앱은 자기 항목을 지우거나(`onDisconnect`, 다른 앱으로 넘어갈 때) `challengesEnabled`만 바꾼다.
class OnlineUserRepository {
  final FirebaseDatabase database;
  final FirebaseFunctions functions;

  /// 대국 서버 주소를 돌려준다. 운영 주소가 없는 빌드에서도 앱이 켜지도록 부를 때 구한다.
  final Uri Function() getServerUrl;

  OnlineUserRepository({required this.database, required this.functions, required this.getServerUrl});

  static const _path = 'online_users';

  /// 대국실 접속자 전체를 듣는다. uid별 항목이다.
  Stream<Map<String, OnlineUser>> watchOnlineUsers() => database.ref(_path).onValue.map(_decodeAll);

  /// [uid]의 항목을 듣는다. 대국실에 없으면 null을 보낸다.
  Stream<OnlineUser?> watchOnlineUser(String uid) => database.ref('$_path/$uid').onValue.map(_decodeOne);

  /// RTDB 연결이 끊기면 [uid]의 항목을 지우도록 걸어 둔다. [enterLobby]보다 먼저 건다.
  Future<void> setRemoveOnDisconnect(String uid) => database.ref('$_path/$uid').onDisconnect().remove();

  /// 대국 서버가 [uid]의 항목을 지금 닉네임, 급수, 상태, 신청 받기로 쓴다.
  Future<void> enterLobby() async {
    await callGameServer(functions, getServerUrl(), 'enterLobby', null);
  }

  /// [uid]의 항목을 지운다. 다른 앱으로 넘어갈 때 쓴다.
  Future<void> removeOnlineUser(String uid) => database.ref('$_path/$uid').remove();

  /// [uid]의 항목이 있으면 신청 받기를 바꾼다. 보안 규칙이 항목이 없을 때는 막는다.
  Future<void> updateChallengesEnabled(String uid, bool enabled) =>
      database.ref('$_path/$uid/challengesEnabled').set(enabled);

  static Map<String, OnlineUser> _decodeAll(DatabaseEvent event) {
    return {
      for (final child in event.snapshot.children)
        child.key!: OnlineUser.fromJson(convertDatabaseValue(child.value) as Map<String, dynamic>),
    };
  }

  static OnlineUser? _decodeOne(DatabaseEvent event) {
    final value = event.snapshot.value;
    return value == null ? null : OnlineUser.fromJson(convertDatabaseValue(value) as Map<String, dynamic>);
  }
}
