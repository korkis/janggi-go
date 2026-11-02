import 'package:janggi_core/janggi_core.dart';

import '../http/callable.dart';
import '../logging.dart';
import '../services/game_rules.dart';
import '../services/game_service.dart';
import 'param_checks.dart';

/// `playMove` 파라미터.
class PlayMoveParams {
  final String gameId;

  /// 이 수가 몇 번째 수인지(0부터).
  final int moveIndex;
  final Move move;

  const PlayMoveParams({required this.gameId, required this.moveIndex, required this.move});
}

/// 파라미터: `gameId`, `moveIndex`(0 이상 정수), `move`(수 표기 또는 `pass`).
PlayMoveParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  final moveIndex = params['moveIndex'];
  if (moveIndex is! int || moveIndex < 0) {
    throw const CallableException.invalidArgument('moveIndex는 0 이상 정수여야 합니다');
  }
  final moveText = params['move'];
  if (moveText is! String) {
    throw const CallableException.invalidArgument('move는 문자열이어야 합니다');
  }
  final Move move;
  try {
    move = Move.parse(moveText);
  } on FormatException {
    throw const CallableException.invalidArgument('move는 수 표기여야 합니다');
  }
  return PlayMoveParams(gameId: requireGameId(params, 'gameId'), moveIndex: moveIndex, move: move);
}

/// 수 또는 한수쉼을 둔다(`docs/server.md`의 수). 같은 수를 다시 보내면 성공으로 본다.
///
/// 수 판정은 `janggi_core`, 시계는 서버가 받은 시각으로 계산한다.
class PlayMoveEndpoint extends CallableEndpoint {
  final GameService gameService;
  final GameLogger logger;

  PlayMoveEndpoint({required this.gameService, required this.logger});

  @override
  String get name => 'playMove';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    final nowMs = request.receivedAt.millisecondsSinceEpoch;
    final game = await gameService.updateGame(
      params.gameId,
      now: request.receivedAt,
      action: (game) => playMove(game, requirePlayerSide(game, request.uid), params.moveIndex, params.move, nowMs),
    );
    logger.info('playMove 성공', {
      'gameId': params.gameId,
      'uid': request.uid,
      'moveIndex': params.moveIndex,
      'phase': game.state.phase.name,
    });
    return null;
  }
}
