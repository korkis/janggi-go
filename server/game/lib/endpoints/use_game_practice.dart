import '../http/callable.dart';
import '../services/game_item_service.dart';
import 'param_checks.dart';

/// `useGamePractice` 파라미터.
class UseGamePracticeParams {
  final String gameId;

  /// 앱이 보여준 값. 지금 값과 다르면 받지 않는다.
  final int coinCost;

  const UseGamePracticeParams({required this.gameId, required this.coinCost});
}

/// 파라미터: `gameId`, `coinCost`(1 이상의 정수).
UseGamePracticeParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  final coinCost = params['coinCost'];
  if (coinCost is! int || coinCost < 1) {
    throw const CallableException.invalidArgument('coinCost는 1 이상의 정수여야 합니다');
  }
  return UseGamePracticeParams(gameId: requireGameId(params, 'gameId'), coinCost: coinCost);
}

/// 엽전을 내고 이 판의 놓아보기를 연다(`docs/server.md`의 시간 연장과 놓아보기).
class UseGamePracticeEndpoint extends CallableEndpoint {
  final GameItemService gameItemService;

  UseGamePracticeEndpoint({required this.gameItemService});

  @override
  String get name => 'useGamePractice';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    await gameItemService.useGamePractice(
      params.gameId,
      uid: request.uid,
      coinCost: params.coinCost,
      now: request.receivedAt,
    );
    return null;
  }
}
