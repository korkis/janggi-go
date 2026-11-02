import '../http/task_handler.dart';
import '../logging.dart';
import '../tasks/task_scheduler.dart';

/// `/tasks/devPing` 본문.
class DevPingTaskParams {
  final String uid;

  /// `devPing`을 받은 시각.
  final DateTime requestedAt;

  const DevPingTaskParams({required this.uid, required this.requestedAt});
}

/// 본문: `uid`(문자열), `requestedAt`(ms).
DevPingTaskParams validateParams(Object? requestParams) {
  if (requestParams is! Map<String, Object?>) {
    throw const InvalidTaskPayloadException('본문은 객체여야 합니다');
  }
  final uid = requestParams['uid'];
  final requestedAt = requestParams['requestedAt'];
  if (uid is! String || uid.isEmpty) {
    throw const InvalidTaskPayloadException('uid가 없습니다');
  }
  if (requestedAt is! int) {
    throw const InvalidTaskPayloadException('requestedAt이 없습니다');
  }
  return DevPingTaskParams(uid: uid, requestedAt: DateTime.fromMillisecondsSinceEpoch(requestedAt, isUtc: true));
}

/// 개발용 예약 작업. 에뮬레이터에서만 연다. `devPing`이 예약한 작업이 돌았음을 로그로 남긴다.
class DevPingTaskEndpoint extends TaskEndpoint {
  final GameLogger logger;

  /// 작업이 돌 때마다 부른다. 테스트가 작업이 돌았는지 확인할 때 쓴다.
  final void Function(DevPingTaskParams params)? onRun;

  DevPingTaskEndpoint({required this.logger, this.onRun});

  @override
  TaskName get name => TaskName.devPing;

  @override
  Future<void> handle(TaskRequest request, Object? payload) async {
    final requestParams = payload;
    final params = validateParams(requestParams);
    final delayMs = request.receivedAt.difference(params.requestedAt).inMilliseconds;
    logger.info('devPing task 실행', {'uid': params.uid, 'delayMs': delayMs, 'retryCount': request.retryCount});
    onRun?.call(params);
  }
}
