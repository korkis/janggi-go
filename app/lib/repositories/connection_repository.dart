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
  Future<String> createConnection(String uid, {required bool foreground}) async {
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
      },
    });
    // 보안 규칙이 연결의 필드를 모두 요구하므로 연결을 쓴 뒤에 건다.
    await userRef.child(connectionId).onDisconnect().update({'online': false});
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

  /// 살아 있음을 알린다.
  Future<void> updateLastSeenAt(String uid, String connectionId) async {
    await database.ref('$_path/$uid/$connectionId').update({'lastSeenAt': ServerValue.timestamp});
  }

  static bool _decodeConnected(DatabaseEvent event) => event.snapshot.value == true;

  static List<Connection> _decodeConnections(DatabaseEvent event) {
    return [
      for (final child in event.snapshot.children)
        Connection.fromJson(convertDatabaseValue(child.value) as Map<String, dynamic>),
    ];
  }
}
