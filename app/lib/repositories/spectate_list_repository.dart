import 'package:firebase_database/firebase_database.dart';

import '../models/spectate_list_entry.dart';
import 'game_repository.dart';

/// RTDB `spectate_list`. 관전 목록 카드다. 대국 서버만 쓰고 로그인하지 않아도 읽는다(`docs/database.md`).
class SpectateListRepository {
  final FirebaseDatabase database;

  SpectateListRepository({required this.database});

  static const _path = 'spectate_list';

  /// 관전 목록에 보이는 대국 전체. 정렬은 하지 않는다. 실시간으로 바뀌지 않는 목록이라 한 번 읽는다.
  Future<List<({String gameId, SpectateListEntry entry})>> getEntries() async {
    final snapshot = await database.ref(_path).get();
    return [
      for (final child in snapshot.children)
        (
          gameId: child.key!,
          entry: SpectateListEntry.fromJson(convertDatabaseValue(child.value) as Map<String, dynamic>),
        ),
    ];
  }

  /// [gameId]의 카드를 듣는다. 관전 화면의 "N명 보는 중"에 쓴다. 목록에 없는 대국(비공개 방, 끝난 대국)이면 null을 보낸다.
  Stream<SpectateListEntry?> watchEntry(String gameId) => database.ref('$_path/$gameId').onValue.map(_decodeEntry);

  static SpectateListEntry? _decodeEntry(DatabaseEvent event) {
    final value = event.snapshot.value;
    return value == null ? null : SpectateListEntry.fromJson(convertDatabaseValue(value) as Map<String, dynamic>);
  }
}
