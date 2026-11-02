import 'package:firebase_database/firebase_database.dart';

/// RTDB `.info/serverTimeOffset`. 앱은 이 값으로 서버 시각을 어림해 대국 시계를 그린다(`docs/server.md`의 시계).
class ServerTimeRepository {
  final FirebaseDatabase database;

  ServerTimeRepository({required this.database});

  /// 서버 시각 − 기기 시각. 연결이 바뀔 때마다 다시 보낸다.
  Stream<Duration> watchServerTimeOffset() => database.ref('.info/serverTimeOffset').onValue.map(_decodeOffset);

  static Duration _decodeOffset(DatabaseEvent event) {
    return Duration(milliseconds: (event.snapshot.value as num).round());
  }
}
