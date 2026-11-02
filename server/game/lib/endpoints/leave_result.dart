import '../http/callable.dart';
import '../services/rematch_service.dart';
import 'param_checks.dart';

/// `leaveResult` 파라미터.
class LeaveResultParams {
  final String gameId;

  const LeaveResultParams({required this.gameId});
}

/// 파라미터: `gameId`.
LeaveResultParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  return LeaveResultParams(gameId: requireGameId(params, 'gameId'));
}

/// 결과 화면을 나간다. 기다리던 다시 두기를 취소한다(`docs/server.md`의 다시 두기).
class LeaveResultEndpoint extends CallableEndpoint {
  final RematchService rematchService;

  LeaveResultEndpoint({required this.rematchService});

  @override
  String get name => 'leaveResult';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    await rematchService.leaveResult(params.gameId, uid: request.uid, now: request.receivedAt);
    return null;
  }
}
