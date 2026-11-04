import 'package:firebase_database/firebase_database.dart';

import '../models/connection.dart';
import 'game_repository.dart';

/// RTDB `connections/{uid}/{connectionId}`와 그 연결의 바탕인 `.info/connected`(`docs/server.md`의 접속 끊김).
///
/// 앱은 RTDB에 연결될 때마다 연결 하나를 새로 만들고 지난 연결을 지운다. 시각은 보안 규칙에 맞춰 서버 시각으로만 쓴다.
class ConnectionRepository {
  final FirebaseDatabase database;

  ConnectionRepository({required this.database});

  static const _path = 'connections';

  /// 이 기기가 RTDB 서버에 연결되어 있는지. 연결이 바뀔 때마다 보낸다.
  Stream<bool> watchConnected() => database.ref('.info/connected').onValue.map(_decodeConnected);

  /// [uid]의 연결들을 듣는다.
  Stream<List<Connection>> watchConnections(String uid) => database.ref('$_path/$uid').onValue.map(_decodeConnections);

  /// 새 연결을 만들고 지난 연결을 지운 뒤, 연결이 끊기면 `online`을 false로 바꾸도록 걸어 둔다. 만든 연결 ID를 돌려준다.
  /// [tabHidden]은 웹만 넘긴다. null이면 쓰지 않는다.
  Future<String> createConnection(String uid, {required bool foreground, bool? tabHidden}) async {
    final userRef = database.ref('$_path/$uid');
    final previous = await userRef.get();
    final connectionId = userRef.push().key!;
    await userRef.update({
      for (final child in previous.children) child.key!: null,
      connectionId: {
        'online': true,
        'foreground': foreground,
        'activeSince': ServerValue.timestamp,
        'lastSeenAt': ServerValue.timestamp,
        'tabHidden': ?tabHidden,
      },
    });
    // 보안 규칙이 연결의 필드를 모두 요구하므로 연결을 쓴 뒤에 건다.
    await _addOnDisconnect(userRef.child(connectionId), stampLastSeenAt: tabHidden == true);
    return connectionId;
  }

  /// 앱이 화면에 돌아왔다. 지금을 `activeSince`로 쓴다.
  Future<void> markForeground(String uid, String connectionId) async {
    await database.ref('$_path/$uid/$connectionId').update({
      'foreground': true,
      'activeSince': ServerValue.timestamp,
      'lastSeenAt': ServerValue.timestamp,
    });
  }

  /// 다른 앱으로 넘어갔다.
  Future<void> markBackground(String uid, String connectionId) async {
    await database.ref('$_path/$uid/$connectionId').update({'foreground': false, 'lastSeenAt': ServerValue.timestamp});
  }

  /// 웹 탭이 숨겨졌다. 웹은 `foreground`를 바꾸지 않는다. 숨긴 탭은 브라우저가 heartbeat를 늦추거나 멈추므로, 탭을 닫거나
  /// 네트워크가 끊길 때 `onDisconnect`가 그 시각을 `lastSeenAt`으로 쓰게 다시 건다.
  Future<void> markTabHidden(String uid, String connectionId) async {
    final ref = database.ref('$_path/$uid/$connectionId');
    await ref.update({'tabHidden': true, 'lastSeenAt': ServerValue.timestamp});
    // 앞서 건 `online: false`를 지우지 않고 더한다. 지운 사이에 끊기면 숨긴 탭이 계속 연결된 것으로 남기 때문이다.
    await _addOnDisconnect(ref, stampLastSeenAt: true);
  }

  /// 웹 탭이 다시 보인다. 지금을 `activeSince`로 쓰고, `onDisconnect`는 앱과 같이 `online: false`만 쓰게 다시 건다.
  Future<void> markTabVisible(String uid, String connectionId) async {
    final ref = database.ref('$_path/$uid/$connectionId');
    await ref.update({'tabHidden': false, 'activeSince': ServerValue.timestamp, 'lastSeenAt': ServerValue.timestamp});
    // 숨겼을 때 건 것을 지우고 다시 건다. 그 사이에 끊겨도 보이는 탭은 `presenceStaleSeconds`로 끊긴 것을 알아챈다.
    await ref.onDisconnect().cancel();
    await _addOnDisconnect(ref, stampLastSeenAt: false);
  }

  /// 살아 있음을 알린다.
  Future<void> updateLastSeenAt(String uid, String connectionId) async {
    await database.ref('$_path/$uid/$connectionId').update({'lastSeenAt': ServerValue.timestamp});
  }

  /// 연결이 끊기면 `online`을 false로 바꾸도록 건다. [stampLastSeenAt]이면 끊긴 시각을 `lastSeenAt`으로도 쓴다. 숨긴 웹 탭만
  /// 그렇게 한다. 그 밖에는 마지막 heartbeat를 끊긴 시각으로 본다(`docs/server.md`의 접속 끊김).
  Future<void> _addOnDisconnect(DatabaseReference ref, {required bool stampLastSeenAt}) async {
    await ref.onDisconnect().update({'online': false, if (stampLastSeenAt) 'lastSeenAt': ServerValue.timestamp});
  }

  static bool _decodeConnected(DatabaseEvent event) => event.snapshot.value == true;

  static List<Connection> _decodeConnections(DatabaseEvent event) {
    return [
      for (final child in event.snapshot.children)
        Connection.fromJson(convertDatabaseValue(child.value) as Map<String, dynamic>),
    ];
  }
}
