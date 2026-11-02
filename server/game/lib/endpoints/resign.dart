import '../logging.dart';
import '../http/callable.dart';
import '../services/game_rules.dart';
import '../services/game_service.dart';
import 'param_checks.dart';

/// `resign` 파라미터.
class ResignParams {
  final String gameId;

  const ResignParams({required this.gameId});
}

/// 파라미터: `gameId`.
ResignParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  return ResignParams(gameId: requireGameId(params, 'gameId'));
}

/// 기권한다. 상차림 중에도 할 수 있다(`docs/server.md`의 기권).
class ResignEndpoint extends CallableEndpoint {
  final GameService gameService;
  final GameLogger logger;

  ResignEndpoint({required this.gameService, required this.logger});

  @override
  String get name => 'resign';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    final nowMs = request.receivedAt.millisecondsSinceEpoch;
    await gameService.updateGame(
      params.gameId,
      now: request.receivedAt,
      action: (game) => resign(game, requirePlayerSide(game, request.uid), nowMs),
    );
    logger.info('resign 성공', {'gameId': params.gameId, 'uid': request.uid});
    return null;
  }
}
