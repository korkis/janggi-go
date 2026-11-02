import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../auth/jwt.dart';
import '../auth/task_request_verifier.dart';
import '../clock.dart';
import '../logging.dart';
import '../tasks/task_scheduler.dart';
import 'callable_handler.dart';

/// 예약 작업의 본문이 잘못됐다. `validateParams()`가 던진다. 다시 불러도 같으므로 400으로 답한다.
class InvalidTaskPayloadException implements Exception {
  final String message;

  const InvalidTaskPayloadException(this.message);

  @override
  String toString() => 'InvalidTaskPayloadException: $message';
}

/// 예약 작업 하나의 요청.
class TaskRequest {
  /// 서버가 요청을 받은 시각(UTC). 판정은 이 시각이 아니라 기록된 마감 시각으로 한다(`docs/server.md`의 예약 작업).
  final DateTime receivedAt;

  /// 몇 번째 재시도인지. Cloud Tasks의 `X-CloudTasks-TaskRetryCount`. 에뮬레이터에서는 null.
  final int? retryCount;

  const TaskRequest({required this.receivedAt, required this.retryCount});
}

/// 예약 작업 하나. `POST /tasks/{name}`으로 [TaskScheduler]가 부른다.
///
/// [handle]은 먼저 `final requestParams = payload;`로 받고 비즈니스 로직 전에 `validateParams(requestParams)`를 부른다.
/// 예외를 던지면 500으로 답해 Cloud Tasks가 다시 부른다.
abstract class TaskEndpoint {
  TaskName get name;

  Future<void> handle(TaskRequest request, Object? payload);
}

/// [endpoint]를 부르는 shelf 핸들러. [verifier]를 통과한 요청만 받는다.
Handler createTaskHandler({
  required TaskEndpoint endpoint,
  required TaskRequestVerifier verifier,
  required GameLogger logger,
  Clock clock = utcNow,
}) {
  return (Request httpRequest) async {
    final receivedAt = clock();
    final retryCount = int.tryParse(httpRequest.headers['x-cloudtasks-taskretrycount'] ?? '');
    final fields = {'task': endpoint.name.name, 'retryCount': retryCount};
    final token = getBearerToken(httpRequest);
    if (token == null) {
      logger.warning('task 거절: 토큰이 없습니다', fields);
      return Response.unauthorized(null);
    }
    try {
      await verifier.verify(token);
    } on AuthException catch (error) {
      logger.warning('task 거절: 토큰 검사 실패', {...fields, 'reason': error.message});
      return Response.forbidden(null);
    }
    try {
      final Object? payload;
      try {
        final body = await httpRequest.readAsString();
        payload = body.isEmpty ? null : jsonDecode(body);
      } on FormatException {
        throw const InvalidTaskPayloadException('본문이 JSON이 아닙니다');
      }
      await endpoint.handle(TaskRequest(receivedAt: receivedAt, retryCount: retryCount), payload);
      return Response.ok(null);
    } on InvalidTaskPayloadException catch (error, stackTrace) {
      logger.error('task 본문이 잘못됐습니다', fields: fields, error: error, stackTrace: stackTrace);
      return Response.badRequest();
    } catch (error, stackTrace) {
      logger.error('task 실패', fields: fields, error: error, stackTrace: stackTrace);
      return Response.internalServerError();
    }
  };
}
