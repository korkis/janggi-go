import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:janggi_core/janggi_core.dart';

import '../models/active_game.dart';
import '../models/game_enums.dart';
import '../models/game_error_code.dart';
import '../utils/app_exception.dart';

/// RTDB `games_active`와 대국 서버의 대국 API. 대국 상태는 대국 서버만 쓰고 앱은 듣기만 한다.
class GameRepository {
  final FirebaseDatabase database;
  final FirebaseFunctions functions;

  /// 대국 서버 주소를 돌려준다. 운영 주소가 없는 빌드에서도 앱이 켜지도록 부를 때 구한다.
  final Uri Function() getServerUrl;

  GameRepository({required this.database, required this.functions, required this.getServerUrl});

  /// 대국을 듣는다. 대국이 없거나 지워졌으면 null을 보낸다.
  Stream<ActiveGame?> watchGame(String gameId) => database.ref('games_active/$gameId').onValue.map(_decodeGame);

  /// 개발용. 나와 [opponentNickname]의 대국을 만든다. 대국 서버가 에뮬레이터 모드일 때만 열려 있다.
  /// 두 사람의 `player_states.gameId`가 생기므로 화면은 그 값을 보고 대국으로 간다.
  Future<void> createDevGame({required String opponentNickname, required SideChoice side}) async {
    await _call('devCreateGame', {'opponentNickname': opponentNickname, 'side': side.name});
  }

  /// 상차림을 골라 두거나([confirmed]가 false) 확정한다.
  Future<void> setFormation(String gameId, Formation formation, {required bool confirmed}) async {
    await _call('setFormation', {'gameId': gameId, 'formation': formation.name, 'confirmed': confirmed});
  }

  /// [moveIndex]번째 수(0부터)로 [move]를 둔다. 한수쉼은 [Move.pass]다.
  Future<void> playMove(String gameId, {required int moveIndex, required Move move}) async {
    await _call('playMove', {'gameId': gameId, 'moveIndex': moveIndex, 'move': move.toString()});
  }

  Future<void> resign(String gameId) async {
    await _call('resign', {'gameId': gameId});
  }

  /// 대국 판정을 다시 보게 한다. 상대 연결이 끊기거나 돌아온 것, 상대 시계가 0이 된 것, 내가 돌아온 것을 보면 부른다.
  Future<void> checkGame(String gameId) async {
    await _call('checkGame', {'gameId': gameId});
  }

  /// 빠른 대국 대기열에 들어가고 서버가 바로 한 번 상대를 찾는다. 찾았으면 새 대국 ID, 아니면 null을 돌려준다.
  /// 이미 대기열에 있으면 기다린 시간을 그대로 두고 다시 찾기만 한다.
  Future<String?> joinQuickQueue() async {
    final result = await _call('joinQuickQueue', null);
    return result['gameId'] as String?;
  }

  /// 빠른 대국 대기열에서 나온다. 그새 대국이 만들어졌으면 서버가 `busy`로 거절한다.
  Future<void> leaveQuickQueue() async {
    await _call('leaveQuickQueue', null);
  }

  /// 끝난 대국 [gameId]의 다시 두기를 누른다. 두 사람이 모두 눌러 새 대국이 정해졌으면 그 ID, 상대를 기다리면 null.
  Future<String?> requestRematch(String gameId) async {
    final result = await _call('requestRematch', {'gameId': gameId});
    return result['gameId'] as String?;
  }

  /// 결과 화면을 나간다. 기다리던 다시 두기를 취소한다.
  Future<void> leaveResult(String gameId) async {
    await _call('leaveResult', {'gameId': gameId});
  }

  /// 대국 서버 API를 Callable 프로토콜로 부르고 결과 객체를 돌려준다. 결과가 없으면 빈 Map이다.
  /// 서버가 알려 준 거절 사유는 [AppException]으로 바꾼다.
  Future<Map<String, Object?>> _call(String name, Map<String, Object?>? data) async {
    final callable = functions.httpsCallableFromUrl(getServerUrl().resolve(name).toString());
    try {
      final result = await callable.call<Object?>(data);
      final value = result.data;
      return value is Map ? {for (final entry in value.entries) entry.key.toString(): entry.value} : const {};
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final code = details is Map ? GameErrorCode.fromName(details['code']) : null;
      final exception = code == null ? null : AppException.fromGameErrorCode(code);
      if (exception == null) {
        rethrow;
      }
      throw exception;
    }
  }

  static ActiveGame? _decodeGame(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value == null) {
      return null;
    }
    return ActiveGame.fromJson(convertDatabaseValue(value) as Map<String, dynamic>);
  }
}

/// RTDB SDK가 돌려준 값(`Map<Object?, Object?>`)을 JSON 모델이 읽는 `Map<String, dynamic>`으로 바꾼다.
Object? convertDatabaseValue(Object? value) {
  return switch (value) {
    Map() => {for (final entry in value.entries) entry.key.toString(): convertDatabaseValue(entry.value)},
    List() => [for (final item in value) convertDatabaseValue(item)],
    _ => value,
  };
}
