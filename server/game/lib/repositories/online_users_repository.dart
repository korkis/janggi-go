import '../firebase/rtdb_client.dart';
import '../models/game_enums.dart';
import '../models/online_user.dart';

/// RTDB `online_users/{uid}`. 대국실 접속자 목록이다. 대국 서버가 쓰고, 본인 앱은 자기 항목을 지우거나 `challengesEnabled`만
/// 바꾼다. 대국 상태를 쓴 뒤에 따라 쓰는 파생 데이터다(`docs/server.md`의 동시에 들어온 요청).
class OnlineUsersRepository {
  final RtdbClient rtdb;

  const OnlineUsersRepository({required this.rtdb});

  static const path = 'online_users';

  /// [uid]의 항목. 대국실에 없으면(앱을 닫았거나 다른 앱으로 넘어갔다) null.
  Future<OnlineUser?> getOnlineUser(String uid) async {
    final value = await rtdb.get('$path/$uid');
    return value == null ? null : OnlineUser.fromJson(value as Map<String, dynamic>);
  }

  Future<void> setOnlineUser(String uid, OnlineUser user) => rtdb.put('$path/$uid', user.toJson());

  /// [uid]의 항목이 있으면 상태만 바꾼다. 없으면(대국실에 없다) 만들지 않는다.
  Future<void> updateStatus(String uid, OnlineStatus status) async {
    await rtdb.runTransaction('$path/$uid', (current) {
      if (current is! Map<String, dynamic> || current['status'] == status.name) {
        throw const RtdbTransactionAbort();
      }
      return {...current, 'status': status.name};
    });
  }
}
