import '../http/callable.dart';
import '../models/game_enums.dart';
import '../services/challenge_service.dart';
import 'param_checks.dart';

/// `sendChallenge` 파라미터.
class SendChallengeParams {
  final String toUid;
  final ChallengeOptions options;

  const SendChallengeParams({required this.toUid, required this.options});
}

/// 파라미터: `toUid`(나 아닌 사용자), `roomId?`(방 초대), `senderSide?`(SideChoice), `handicap?`(`remover`, `pieces`).
/// 방 초대면 방 조건을 쓰므로 `senderSide`와 `handicap`을 주지 않는다. 아니면 접장기면 `handicap`만, 아니면 `senderSide`만 준다.
SendChallengeParams validateParams(Object? requestParams, String uid) {
  final params = requireParamsMap(requestParams);
  final toUid = requireUid(params, 'toUid');
  if (toUid == uid) {
    throw const CallableException.invalidArgument('나에게는 신청할 수 없습니다');
  }
  final roomId = params['roomId'] == null ? null : requireRoomId(params, 'roomId');
  final handicap = switch (params['handicap']) {
    null => null,
    final Map<String, Object?> value => requireHandicap(value),
    _ => throw const CallableException.invalidArgument('handicap은 객체여야 합니다'),
  };
  final senderSide = params['senderSide'] == null ? null : requireEnum(params, 'senderSide', SideChoice.values);
  if (roomId != null && (handicap != null || senderSide != null)) {
    throw const CallableException.invalidArgument('방 초대는 방 조건을 쓰므로 senderSide와 handicap을 주지 않습니다');
  }
  if (roomId == null && (handicap == null) == (senderSide == null)) {
    throw const CallableException.invalidArgument('접장기면 handicap, 아니면 senderSide 하나만 줍니다');
  }
  return SendChallengeParams(
    toUid: toUid,
    options: ChallengeOptions(senderSide: senderSide, handicap: handicap, roomId: roomId),
  );
}

/// 대국을 신청한다(`docs/server.md`의 신청). 결과: `challengeId`.
class SendChallengeEndpoint extends CallableEndpoint {
  final ChallengeService challengeService;

  SendChallengeEndpoint({required this.challengeService});

  @override
  String get name => 'sendChallenge';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams, request.uid);
    final challengeId = await challengeService.sendChallenge(
      request.uid,
      request.user,
      params.toUid,
      params.options,
      now: request.receivedAt,
    );
    return {'challengeId': challengeId};
  }
}
