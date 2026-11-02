import '../http/task_handler.dart';
import '../services/quick_match_service.dart';
import '../tasks/task_scheduler.dart';

/// `retryQuickMatch` 본문.
class RetryQuickMatchParams {
  final String uid;

  /// 대기열에 들어온 시각(밀리초). 그새 나갔다 다시 들어왔으면 이 작업은 아무것도 하지 않는다.
  final int joinedAt;

  /// 범위를 넓히는 시각(밀리초). 예약 시각보다 일찍 불려도 이 시각으로 범위를 정한다.
  final int eventAt;

  const RetryQuickMatchParams({required this.uid, required this.joinedAt, required this.eventAt});

  /// 판정 기준 시각. 받은 시각과 [eventAt] 중 늦은 쪽이다.
  DateTime getJudgedAt(DateTime receivedAt) {
    if (receivedAt.millisecondsSinceEpoch >= eventAt) {
      return receivedAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(eventAt, isUtc: true);
  }
}

/// 본문: `uid`(문자열), `joinedAt`(ms), `eventAt`(ms).
RetryQuickMatchParams validateParams(Object? requestParams) {
  if (requestParams is! Map<String, Object?>) {
    throw const InvalidTaskPayloadException('본문은 객체여야 합니다');
  }
  final uid = requestParams['uid'];
  final joinedAt = requestParams['joinedAt'];
  final eventAt = requestParams['eventAt'];
  if (uid is! String || uid.isEmpty) {
    throw const InvalidTaskPayloadException('uid가 없습니다');
  }
  if (joinedAt is! int || eventAt is! int) {
    throw const InvalidTaskPayloadException('joinedAt과 eventAt은 정수여야 합니다');
  }
  return RetryQuickMatchParams(uid: uid, joinedAt: joinedAt, eventAt: eventAt);
}

/// 대기열에 있는 사람의 매칭 범위를 넓혀 다시 찾는다. 나갔거나 매칭됐으면 아무것도 하지 않는다.
class RetryQuickMatchTaskEndpoint extends TaskEndpoint {
  final QuickMatchService quickMatchService;

  RetryQuickMatchTaskEndpoint({required this.quickMatchService});

  @override
  TaskName get name => TaskName.retryQuickMatch;

  @override
  Future<void> handle(TaskRequest request, Object? payload) async {
    final requestParams = payload;
    final params = validateParams(requestParams);
    await quickMatchService.retryMatch(
      params.uid,
      joinedAt: params.joinedAt,
      now: params.getJudgedAt(request.receivedAt),
    );
  }
}
