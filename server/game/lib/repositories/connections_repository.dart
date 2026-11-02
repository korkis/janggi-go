import '../firebase/rtdb_client.dart';
import '../models/connection.dart';

/// RTDB `connections/{uid}/{connectionId}`. 앱이 쓰고 대국 서버는 접속 끊김 판정에 읽기만 한다.
class ConnectionsRepository {
  final RtdbClient rtdb;

  const ConnectionsRepository({required this.rtdb});

  static const path = 'connections';

  /// [uid]의 모든 연결. 없으면 빈 목록.
  Future<List<Connection>> getConnections(String uid) async {
    final value = await rtdb.get('$path/$uid');
    if (value == null) {
      return const [];
    }
    return [
      for (final connection in (value as Map<String, dynamic>).values)
        Connection.fromJson(connection as Map<String, dynamic>),
    ];
  }
}
