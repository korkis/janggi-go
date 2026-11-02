import 'package:janggi_core/janggi_core.dart';

import '../http/callable.dart';
import '../logging.dart';
import '../services/game_rules.dart';
import '../services/game_service.dart';
import 'param_checks.dart';

/// `setFormation` 파라미터.
class SetFormationParams {
  final String gameId;
  final Formation formation;

  /// true면 확정하고, false면 골라 두기만 한다.
  final bool confirmed;

  const SetFormationParams({required this.gameId, required this.formation, required this.confirmed});
}

/// 파라미터: `gameId`, `formation`(Formation), `confirmed`(boolean).
SetFormationParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  final confirmed = params['confirmed'];
  if (confirmed is! bool) {
    throw const CallableException.invalidArgument('confirmed는 boolean이어야 합니다');
  }
  return SetFormationParams(
    gameId: requireGameId(params, 'gameId'),
    formation: requireEnum(params, 'formation', Formation.values),
    confirmed: confirmed,
  );
}

/// 상차림을 골라 두거나(`player_states.setupDraft`) 확정한다(`docs/server.md`의 대국 만들기와 상차림).
///
/// 한이 먼저 확정하고 초는 한이 확정한 뒤 고른다. 자기 차례가 아니면 `notYourTurn`.
class SetFormationEndpoint extends CallableEndpoint {
  final GameService gameService;
  final GameLogger logger;

  SetFormationEndpoint({required this.gameService, required this.logger});

  @override
  String get name => 'setFormation';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    if (!params.confirmed) {
      await gameService.saveSetupDraft(
        params.gameId,
        uid: request.uid,
        formation: params.formation,
        now: request.receivedAt,
      );
      logger.info('setFormation 골라 둠', {'gameId': params.gameId, 'uid': request.uid});
      return null;
    }
    final nowMs = request.receivedAt.millisecondsSinceEpoch;
    await gameService.updateGame(
      params.gameId,
      now: request.receivedAt,
      action: (game) => confirmFormation(game, requirePlayerSide(game, request.uid), params.formation, nowMs),
    );
    logger.info('setFormation 확정', {'gameId': params.gameId, 'uid': request.uid, 'formation': params.formation.name});
    return null;
  }
}
