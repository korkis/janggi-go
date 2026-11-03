import '../firebase/rtdb_client.dart';
import '../models/spectate_list_entry.dart';

/// RTDB `spectate_list/{gameId}`. 관전 목록 카드다. 대국 상태를 쓴 뒤에 따라 쓰는 파생 데이터다
/// (`docs/server.md`의 동시에 들어온 요청).
class SpectateListRepository {
  final RtdbClient rtdb;

  const SpectateListRepository({required this.rtdb});

  static const path = 'spectate_list';

  /// 카드. 없으면 null.
  Future<SpectateListEntry?> getEntry(String gameId) async {
    final value = await rtdb.get('$path/$gameId');
    return value == null ? null : SpectateListEntry.fromJson(value as Map<String, dynamic>);
  }

  Future<void> setEntry(String gameId, SpectateListEntry entry) => rtdb.put('$path/$gameId', entry.toJson());

  Future<void> deleteEntry(String gameId) => rtdb.delete('$path/$gameId');
}
