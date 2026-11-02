import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../clock.dart';
import '../logging.dart';
import 'task_scheduler.dart';

/// 에뮬레이터용 [TaskScheduler]. Cloud Tasks에 에뮬레이터가 없어서 같은 프로세스의 타이머가 대국 서버의 `/tasks/...`를
/// HTTP로 부른다(`docs/server.md`의 개발 환경). 실패하면 Cloud Tasks처럼 간격을 늘려 가며 다시 부른다.
///
/// 프로세스를 끄면 남은 예약은 사라진다.
class LocalTaskScheduler implements TaskScheduler {
  final http.Client httpClient;

  /// `Authorization: Bearer`에 넣는 값. 같은 프로세스의 `LocalTaskVerifier.secret`이다.
  final String secret;
  final GameLogger logger;
  final Clock clock;

  /// 한 작업을 부르는 최대 횟수.
  final int maxAttempts;

  /// 첫 재시도까지 기다리는 시간. 재시도마다 두 배로 늘린다.
  final Duration retryDelay;

  /// 대국 서버 주소. 서버가 포트를 연 뒤에 정한다.
  late Uri serverUri;

  final _timers = <Timer>{};

  // 이미 받은 taskId. Cloud Tasks도 한 번 쓴 이름은 한동안 다시 받지 않는다.
  final _usedTaskIds = <String>{};

  LocalTaskScheduler({
    required this.httpClient,
    required this.secret,
    required this.logger,
    this.clock = utcNow,
    this.maxAttempts = 5,
    this.retryDelay = const Duration(seconds: 1),
  });

  /// 남은 예약을 모두 취소한다.
  void close() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  Future<void> schedule(TaskName task, Map<String, Object?> payload, {required DateTime runAt, String? taskId}) async {
    if (taskId != null) {
      if (!isValidTaskId(taskId)) {
        throw ArgumentError.value(taskId, 'taskId', '영문, 숫자, -, _만 쓸 수 있습니다');
      }
      if (!_usedTaskIds.add(taskId)) {
        logger.debug('schedule 건너뜀: 같은 taskId가 있습니다', {'task': task.name, 'taskId': taskId});
        return;
      }
    }
    final body = jsonEncode(payload);
    var delay = runAt.difference(clock());
    if (delay.isNegative) {
      delay = Duration.zero;
    }
    logger.debug('schedule 예약', {'task': task.name, 'taskId': taskId, 'runAt': runAt, 'delayMs': delay.inMilliseconds});
    _startTimer(delay, () => _run(task, body, taskId, 1));
  }

  void _startTimer(Duration delay, Future<void> Function() callback) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      unawaited(callback());
    });
    _timers.add(timer);
  }

  Future<void> _run(TaskName task, String body, String? taskId, int attempt) async {
    final fields = {'task': task.name, 'taskId': taskId, 'attempt': attempt};
    try {
      final response = await httpClient.post(
        serverUri.replace(path: task.path),
        headers: {'Authorization': 'Bearer $secret', 'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      logger.warning('local task 실패', {...fields, 'statusCode': response.statusCode});
    } catch (error, stackTrace) {
      logger.error('local task 호출 실패', fields: fields, error: error, stackTrace: stackTrace);
    }
    if (attempt >= maxAttempts) {
      logger.error('local task 포기', fields: fields);
      return;
    }
    _startTimer(retryDelay * (1 << (attempt - 1)), () => _run(task, body, taskId, attempt + 1));
  }
}
