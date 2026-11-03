import '../http/task_handler.dart';
import '../services/challenge_service.dart';
import '../tasks/task_scheduler.dart';

/// `expireChallenge` 본문.
class ExpireChallengeParams {
  final String challengeId;

  /// 응답 마감(밀리초). 예약 시각보다 일찍 불려도 이 시각으로 판정한다.
  final int eventAt;

  const ExpireChallengeParams({required this.challengeId, required this.eventAt});

  /// 판정 기준 시각. 받은 시각과 [eventAt] 중 늦은 쪽이다.
  DateTime getJudgedAt(DateTime receivedAt) {
    if (receivedAt.millisecondsSinceEpoch >= eventAt) {
      return receivedAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(eventAt, isUtc: true);
  }
}

/// 본문: `challengeId`(문자열), `eventAt`(ms).
ExpireChallengeParams validateParams(Object? requestParams) {
  if (requestParams is! Map<String, Object?>) {
    throw const InvalidTaskPayloadException('본문은 객체여야 합니다');
  }
  final challengeId = requestParams['challengeId'];
  final eventAt = requestParams['eventAt'];
  if (challengeId is! String || challengeId.isEmpty) {
    throw const InvalidTaskPayloadException('challengeId가 없습니다');
  }
  if (eventAt is! int) {
    throw const InvalidTaskPayloadException('eventAt은 정수여야 합니다');
  }
  return ExpireChallengeParams(challengeId: challengeId, eventAt: eventAt);
}

/// 신청 응답 마감. 응답이 없으면 신청을 `expired`로 바꾸고 연속 거절 횟수를 센다.
class ExpireChallengeTaskEndpoint extends TaskEndpoint {
  final ChallengeService challengeService;

  ExpireChallengeTaskEndpoint({required this.challengeService});

  @override
  TaskName get name => TaskName.expireChallenge;

  @override
  Future<void> handle(TaskRequest request, Object? payload) async {
    final requestParams = payload;
    final params = validateParams(requestParams);
    await challengeService.expireChallenge(params.challengeId, now: params.getJudgedAt(request.receivedAt));
  }
}
