import '../http/callable.dart';
import '../logging.dart';
import '../services/game_rules.dart';
import '../services/game_service.dart';
import 'param_checks.dart';

/// `checkGame` 파라미터.
class CheckGameParams {
  final String gameId;

  const CheckGameParams({required this.gameId});
}

/// 파라미터: `gameId`.
CheckGameParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  return CheckGameParams(gameId: requireGameId(params, 'gameId'));
}

/// 대국 판정을 다시 보게 한다(`docs/server.md`의 판정 다시 보기). 앱이 상대 연결이 끊기거나 돌아온 것, 상대 시계가 0이 된 것,
/// 자기가 돌아온 것을 보면 부른다.
///
/// 판정은 RTDB의 대국과 접속 기록만 보므로 부른 사람이 결과를 바꿀 수 없다. 대국자만 부를 수 있고, 끝난 대국이면 아무것도
/// 하지 않고 성공한다.
class CheckGameEndpoint extends CallableEndpoint {
  final GameService gameService;
  final GameLogger logger;

  CheckGameEndpoint({required this.gameService, required this.logger});

  @override
  String get name => 'checkGame';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    final game = await gameService.updateGame(
      params.gameId,
      now: request.receivedAt,
      action: (game) {
        requirePlayerSide(game, request.uid);
        return game;
      },
    );
    logger.info('checkGame 성공', {
      'gameId': params.gameId,
      'uid': request.uid,
      'phase': game.state.phase.name,
      'version': game.state.version,
    });
    return null;
  }
}
