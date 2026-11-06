import '../http/callable.dart';
import '../services/game_item_service.dart';
import 'param_checks.dart';

/// `useTimeExtension` 파라미터.
class UseTimeExtensionParams {
  final String gameId;

  /// 이 대국에서 몇 번째 시간 연장인지(0부터). 앱이 본 `clock.extensionsUsed`다. 같은 요청을 다시 보내도 한 번만 반영하는 데 쓴다.
  final int extensionIndex;

  /// 앱이 보여준 값. 지금 값과 다르면 받지 않는다.
  final int coinCost;

  const UseTimeExtensionParams({required this.gameId, required this.extensionIndex, required this.coinCost});
}

/// 파라미터: `gameId`, `extensionIndex`(0 이상의 정수), `coinCost`(1 이상의 정수).
UseTimeExtensionParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  final extensionIndex = params['extensionIndex'];
  if (extensionIndex is! int || extensionIndex < 0) {
    throw const CallableException.invalidArgument('extensionIndex는 0 이상의 정수여야 합니다');
  }
  final coinCost = params['coinCost'];
  if (coinCost is! int || coinCost < 1) {
    throw const CallableException.invalidArgument('coinCost는 1 이상의 정수여야 합니다');
  }
  return UseTimeExtensionParams(
    gameId: requireGameId(params, 'gameId'),
    extensionIndex: extensionIndex,
    coinCost: coinCost,
  );
}

/// 엽전을 내고 시간 연장을 쓴다(`docs/server.md`의 시간 연장과 놓아보기).
class UseTimeExtensionEndpoint extends CallableEndpoint {
  final GameItemService gameItemService;

  UseTimeExtensionEndpoint({required this.gameItemService});

  @override
  String get name => 'useTimeExtension';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    await gameItemService.useTimeExtension(
      params.gameId,
      uid: request.uid,
      extensionIndex: params.extensionIndex,
      coinCost: params.coinCost,
      now: request.receivedAt,
    );
    return null;
  }
}
