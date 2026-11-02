import '../http/callable.dart';
import '../logging.dart';
import '../tasks/task_scheduler.dart';

/// `devPing` 파라미터.
class DevPingParams {
  /// 이 시간 뒤에 `devPing` 예약 작업을 부른다. null이면 예약하지 않는다.
  final Duration? taskDelay;

  const DevPingParams({required this.taskDelay});
}

/// `devPing`의 [DevPingParams.taskDelay] 최대값.
const devPingMaxTaskDelay = Duration(seconds: 60);

/// 파라미터: `taskDelaySeconds?`(0~60 정수). 파라미터가 없으면 `data`가 null이어도 된다.
DevPingParams validateParams(Object? requestParams) {
  if (requestParams == null) {
    return const DevPingParams(taskDelay: null);
  }
  if (requestParams is! Map<String, Object?>) {
    throw const CallableException.invalidArgument('data는 객체여야 합니다');
  }
  final taskDelaySeconds = requestParams['taskDelaySeconds'];
  if (taskDelaySeconds == null) {
    return const DevPingParams(taskDelay: null);
  }
  if (taskDelaySeconds is! int || taskDelaySeconds < 0 || taskDelaySeconds > devPingMaxTaskDelay.inSeconds) {
    throw CallableException.invalidArgument('taskDelaySeconds는 0~${devPingMaxTaskDelay.inSeconds} 정수여야 합니다');
  }
  return DevPingParams(taskDelay: Duration(seconds: taskDelaySeconds));
}

/// 개발용 API. 에뮬레이터에서만 연다. 로그인, 프로필 확인, 파라미터 검증, 예약 작업이 도는지 확인한다.
///
/// 결과: `uid`, `nickname`, `rankLevel`, `receivedAt`(서버가 받은 시각, ms), `taskScheduled`.
class DevPingEndpoint extends CallableEndpoint {
  final TaskScheduler taskScheduler;
  final GameLogger logger;

  DevPingEndpoint({required this.taskScheduler, required this.logger});

  @override
  String get name => 'devPing';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    final taskDelay = params.taskDelay;
    if (taskDelay != null) {
      await taskScheduler.schedule(TaskName.devPing, {
        'uid': request.uid,
        'requestedAt': request.receivedAt.millisecondsSinceEpoch,
      }, runAt: request.receivedAt.add(taskDelay));
    }
    logger.info('devPing 성공', {'uid': request.uid, 'taskDelayMs': taskDelay?.inMilliseconds});
    return {
      'uid': request.uid,
      'nickname': request.user.nickname,
      'rankLevel': request.user.rankLevel,
      'receivedAt': request.receivedAt.millisecondsSinceEpoch,
      'taskScheduled': taskDelay != null,
    };
  }
}
