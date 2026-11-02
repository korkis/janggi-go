import 'dart:math';

import '../firebase/rtdb_client.dart';
import '../models/active_game.dart';

/// RTDB `games_active/{gameId}`. 진행 중이거나 막 끝난 대국이다.
///
/// 한 대국의 변경은 노드 전체를 ETag 조건부 쓰기로 바꾼다(`docs/server.md`의 동시에 들어온 요청).
class ActiveGamesRepository {
  final RtdbClient rtdb;
  final Random _random;

  ActiveGamesRepository({required this.rtdb, Random? random}) : _random = random ?? Random.secure();

  static const path = 'games_active';

  static const _idCharacters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static const _idLength = 20;

  /// 추측할 수 없는 20자 대국 ID.
  String createGameId() => List.generate(_idLength, (_) => _idCharacters[_random.nextInt(_idCharacters.length)]).join();

  /// 대국. 없으면 null.
  Future<ActiveGame?> getGame(String gameId) async {
    final value = await rtdb.get('$path/$gameId');
    return value == null ? null : _decode(value);
  }

  Future<void> createGame(String gameId, ActiveGame game) => rtdb.put('$path/$gameId', game.toJson());

  /// 대국을 [transform] 결과로 바꾼다. 다른 요청이 먼저 썼으면 새 값으로 [transform]을 다시 부른다.
  ///
  /// [transform]은 대국이 없으면 null을 받는다. null을 돌려주면 쓰지 않고 이 함수도 null을 돌려준다.
  Future<ActiveGame?> updateGame(String gameId, ActiveGame? Function(ActiveGame? game) transform) async {
    final written = await rtdb.runTransaction('$path/$gameId', (current) {
      final next = transform(current == null ? null : _decode(current));
      if (next == null) {
        throw const RtdbTransactionAbort();
      }
      return next.toJson();
    });
    return written == null ? null : _decode(written);
  }

  Future<void> deleteGame(String gameId) => rtdb.delete('$path/$gameId');

  // RTDB REST가 돌려준 JSON. 쓴 값을 그대로 돌려받을 때도 같은 경로로 읽어 모양을 맞춘다.
  static ActiveGame _decode(Object value) => ActiveGame.fromJson(value as Map<String, dynamic>);
}
