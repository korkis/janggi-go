import '../http/callable.dart';
import '../services/rematch_service.dart';
import 'param_checks.dart';

/// `requestRematch` 파라미터.
class RequestRematchParams {
  /// 끝난 대국.
  final String gameId;

  const RequestRematchParams({required this.gameId});
}

/// 파라미터: `gameId`.
RequestRematchParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  return RequestRematchParams(gameId: requireGameId(params, 'gameId'));
}

/// 결과 화면에서 다시 두기를 누른다(`docs/server.md`의 다시 두기). 두 사람이 모두 누르면 새 대국을 만든다.
///
/// 결과: `gameId`(새 대국이 정해졌으면 그 ID, 상대를 기다리면 null).
class RequestRematchEndpoint extends CallableEndpoint {
  final RematchService rematchService;

  RequestRematchEndpoint({required this.rematchService});

  @override
  String get name => 'requestRematch';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    final gameId = await rematchService.requestRematch(params.gameId, uid: request.uid, now: request.receivedAt);
    return {'gameId': gameId};
  }
}
