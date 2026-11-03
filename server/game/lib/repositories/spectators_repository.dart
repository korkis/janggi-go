import '../firebase/rtdb_client.dart';

/// RTDB `spectators/{gameId}/{viewerId}`. 관전 화면을 연 앱이 쓰고 `onDisconnect`로 지우는 표시다. 대국 서버는 세기만 한다
/// (`docs/server.md`의 관전자 수).
class SpectatorsRepository {
  final RtdbClient rtdb;

  const SpectatorsRepository({required this.rtdb});

  static const path = 'spectators';

  /// [gameId]를 보고 있는 관전자 수. 자식 값은 받지 않고 얕게 읽는다.
  Future<int> countSpectators(String gameId) async {
    final value = await rtdb.get('$path/$gameId', shallow: true);
    return value is Map ? value.length : 0;
  }

  /// 지워진 대국의 표시를 모두 지운다. 남은 관전자의 `onDisconnect`가 나중에 지워도 같다.
  Future<void> deleteSpectators(String gameId) => rtdb.delete('$path/$gameId');
}
