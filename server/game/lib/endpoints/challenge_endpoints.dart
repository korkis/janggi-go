import '../http/callable.dart';
import '../services/challenge_service.dart';
import 'param_checks.dart';

// 신청 하나에 대한 응답과 취소 API다(`docs/server.md`의 신청). 파라미터가 `challengeId`에서 시작해 한 파일에 둔다.

/// 신청 API의 파라미터. [accepted]는 `respondChallenge`만 쓴다.
class ChallengeParams {
  final String challengeId;
  final bool? accepted;

  const ChallengeParams({required this.challengeId, required this.accepted});
}

/// 파라미터: `challengeId`, [requireAccepted]면(`respondChallenge`) `accepted`(boolean).
ChallengeParams validateParams(Object? requestParams, {required bool requireAccepted}) {
  final params = requireParamsMap(requestParams);
  final challengeId = requireChallengeId(params, 'challengeId');
  final accepted = params['accepted'];
  if (requireAccepted && accepted is! bool) {
    throw const CallableException.invalidArgument('accepted는 boolean이어야 합니다');
  }
  return ChallengeParams(challengeId: challengeId, accepted: accepted is bool ? accepted : null);
}

/// 받은 사람이 신청을 수락하거나 거절한다. 결과: 수락해서 만든 대국 `gameId` 또는 들어간 방 `roomId`(방 초대). 거절이면 둘 다
/// null.
class RespondChallengeEndpoint extends CallableEndpoint {
  final ChallengeService challengeService;

  RespondChallengeEndpoint({required this.challengeService});

  @override
  String get name => 'respondChallenge';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams, requireAccepted: true);
    final response = await challengeService.respondChallenge(
      params.challengeId,
      uid: request.uid,
      user: request.user,
      accepted: params.accepted!,
      now: request.receivedAt,
    );
    return {'gameId': response.gameId, 'roomId': response.roomId};
  }
}

/// 보낸 사람이 응답을 기다리는 신청을 취소한다. 결과는 없다.
class CancelChallengeEndpoint extends CallableEndpoint {
  final ChallengeService challengeService;

  CancelChallengeEndpoint({required this.challengeService});

  @override
  String get name => 'cancelChallenge';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams, requireAccepted: false);
    await challengeService.cancelChallenge(params.challengeId, uid: request.uid, now: request.receivedAt);
    return null;
  }
}
