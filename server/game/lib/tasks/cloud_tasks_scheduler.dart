import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logging.dart';
import '../server_environment.dart';
import 'task_scheduler.dart';

/// 운영용 [TaskScheduler]. Cloud Tasks REST API(v2)로 대국 서버를 부르는 HTTP 작업을 만든다.
///
/// 작업에는 [CloudTasksEnvironment.serviceAccountEmail]의 OIDC 토큰이 붙고, 대국 서버는 그 토큰만 받는다.
/// 대국 서버의 서비스 계정에 큐의 `roles/cloudtasks.enqueuer`와 작업 서비스 계정의 `roles/iam.serviceAccountUser`가 필요하다.
class CloudTasksScheduler implements TaskScheduler {
  /// 인증 헤더를 붙이는 클라이언트(`AuthorizedClient`).
  final http.Client httpClient;
  final String projectId;
  final CloudTasksEnvironment environment;
  final GameLogger logger;

  const CloudTasksScheduler({
    required this.httpClient,
    required this.projectId,
    required this.environment,
    required this.logger,
  });

  String get queueName => 'projects/$projectId/locations/${environment.location}/queues/${environment.queue}';

  @override
  Future<void> schedule(TaskName task, Map<String, Object?> payload, {required DateTime runAt, String? taskId}) async {
    if (taskId != null && !isValidTaskId(taskId)) {
      throw ArgumentError.value(taskId, 'taskId', '영문, 숫자, -, _만 쓸 수 있습니다');
    }
    final audience = environment.serverUrl.toString();
    final body = {
      'task': {
        if (taskId != null) 'name': '$queueName/tasks/$taskId',
        'scheduleTime': runAt.toUtc().toIso8601String(),
        'httpRequest': {
          'httpMethod': 'POST',
          'url': environment.serverUrl.replace(path: task.path).toString(),
          'headers': {'Content-Type': 'application/json'},
          'body': base64.encode(utf8.encode(jsonEncode(payload))),
          'oidcToken': {'serviceAccountEmail': environment.serviceAccountEmail, 'audience': audience},
        },
      },
    };
    final response = await httpClient.post(
      Uri.parse('https://cloudtasks.googleapis.com/v2/$queueName/tasks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 409 && taskId != null) {
      // 같은 이름의 작업이 이미 있거나 최근에 돌았다.
      logger.debug('schedule 건너뜀: 같은 taskId가 있습니다', {'task': task.name, 'taskId': taskId});
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('Cloud Tasks 작업을 만들지 못했습니다: ${response.statusCode} ${response.body}');
    }
    logger.debug('schedule 예약', {'task': task.name, 'taskId': taskId, 'runAt': runAt});
  }
}
