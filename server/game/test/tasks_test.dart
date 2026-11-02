import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:janggigo_game/auth/task_request_verifier.dart';
import 'package:janggigo_game/endpoints/dev_ping_task.dart';
import 'package:janggigo_game/http/task_handler.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/server_environment.dart';
import 'package:janggigo_game/tasks/cloud_tasks_scheduler.dart';
import 'package:janggigo_game/tasks/local_task_scheduler.dart';
import 'package:janggigo_game/tasks/task_scheduler.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  final logger = GameLogger(format: LogFormat.text, minSeverity: LogSeverity.error, write: (_) {});

  group('createTaskHandler', () {
    final verifier = LocalTaskVerifier.random();
    final runs = <DevPingTaskParams>[];
    final handler = createTaskHandler(
      endpoint: DevPingTaskEndpoint(logger: logger, onRun: runs.add),
      verifier: verifier,
      logger: logger,
    );

    Request taskRequest(Object? body, {String? token}) => Request(
      'POST',
      Uri.parse('http://localhost/tasks/devPing'),
      headers: {'Authorization': ?token == null ? null : 'Bearer $token'},
      body: jsonEncode(body),
    );

    setUp(runs.clear);

    test('토큰이 맞으면 작업을 부른다', () async {
      final response = await handler(taskRequest({'uid': 'user-1', 'requestedAt': 0}, token: verifier.secret));
      expect(response.statusCode, 200);
      expect(runs.single.uid, 'user-1');
    });

    test('토큰이 없거나 틀리면 부르지 않는다', () async {
      expect((await handler(taskRequest({'uid': 'user-1', 'requestedAt': 0}))).statusCode, 401);
      expect((await handler(taskRequest({'uid': 'user-1', 'requestedAt': 0}, token: 'wrong'))).statusCode, 403);
      expect(runs, isEmpty);
    });

    test('본문이 잘못되면 400', () async {
      final response = await handler(taskRequest({'uid': 'user-1'}, token: verifier.secret));
      expect(response.statusCode, 400);
      expect(runs, isEmpty);
    });
  });

  group('LocalTaskScheduler', () {
    late HttpServer server;
    late LocalTaskScheduler scheduler;
    late LocalTaskVerifier verifier;
    late Future<Response> Function(Request request) respond;

    setUp(() async {
      verifier = LocalTaskVerifier.random();
      server = await shelf_io.serve((Request request) => respond(request), InternetAddress.loopbackIPv4, 0);
      scheduler = LocalTaskScheduler(
        httpClient: http.Client(),
        secret: verifier.secret,
        logger: logger,
        retryDelay: const Duration(milliseconds: 10),
      )..serverUri = Uri.parse('http://127.0.0.1:${server.port}');
    });

    tearDown(() async {
      scheduler.close();
      await server.close(force: true);
    });

    test('정한 시각에 /tasks/{name}을 secret과 본문으로 부른다', () async {
      final received = Completer<Request>();
      final bodies = <String>[];
      respond = (request) async {
        bodies.add(await request.readAsString());
        received.complete(request);
        return Response.ok(null);
      };

      final scheduledAt = DateTime.now().toUtc();
      await scheduler.schedule(TaskName.devPing, {
        'uid': 'user-1',
      }, runAt: scheduledAt.add(const Duration(milliseconds: 200)));
      final request = await received.future.timeout(const Duration(seconds: 5));

      expect(DateTime.now().toUtc().difference(scheduledAt), greaterThanOrEqualTo(const Duration(milliseconds: 190)));
      expect(request.url.path, 'tasks/devPing');
      expect(request.headers['authorization'], 'Bearer ${verifier.secret}');
      expect(jsonDecode(bodies.single), {'uid': 'user-1'});
    });

    test('실패하면 다시 부른다', () async {
      var attempts = 0;
      final succeeded = Completer<void>();
      respond = (request) async {
        attempts++;
        if (attempts < 3) {
          return Response.internalServerError();
        }
        succeeded.complete();
        return Response.ok(null);
      };

      await scheduler.schedule(TaskName.devPing, {}, runAt: DateTime.now().toUtc());
      await succeeded.future.timeout(const Duration(seconds: 5));
      expect(attempts, 3);
    });

    test('같은 taskId는 한 번만 예약한다', () async {
      var calls = 0;
      respond = (request) async {
        calls++;
        return Response.ok(null);
      };

      final runAt = DateTime.now().toUtc();
      await scheduler.schedule(TaskName.devPing, {}, runAt: runAt, taskId: 'game-1-v3');
      await scheduler.schedule(TaskName.devPing, {}, runAt: runAt, taskId: 'game-1-v3');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(calls, 1);
    });

    test('잘못된 taskId는 거절한다', () async {
      expect(
        () => scheduler.schedule(TaskName.devPing, {}, runAt: DateTime.now().toUtc(), taskId: 'a/b'),
        throwsArgumentError,
      );
    });
  });

  group('CloudTasksScheduler', () {
    final environment = CloudTasksEnvironment(
      location: 'asia-northeast3',
      queue: 'game-tasks',
      serverUrl: Uri.parse('https://game-abc-du.a.run.app'),
      serviceAccountEmail: 'game-tasks@janggi-go.iam.gserviceaccount.com',
    );

    test('OIDC 토큰이 붙은 HTTP 작업을 만든다', () async {
      late http.Request sent;
      final scheduler = CloudTasksScheduler(
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response('{}', 200);
        }),
        projectId: 'janggi-go',
        environment: environment,
        logger: logger,
      );

      await scheduler.schedule(
        TaskName.devPing,
        {'uid': 'user-1'},
        runAt: DateTime.utc(2026, 11, 2, 12, 0, 30),
        taskId: 'devPing-user-1',
      );

      const queue = 'projects/janggi-go/locations/asia-northeast3/queues/game-tasks';
      expect(sent.url.toString(), 'https://cloudtasks.googleapis.com/v2/$queue/tasks');
      final task = (jsonDecode(sent.body) as Map)['task'] as Map;
      expect(task['name'], '$queue/tasks/devPing-user-1');
      expect(task['scheduleTime'], '2026-11-02T12:00:30.000Z');
      final httpRequest = task['httpRequest'] as Map;
      expect(httpRequest['url'], 'https://game-abc-du.a.run.app/tasks/devPing');
      expect(httpRequest['httpMethod'], 'POST');
      expect(utf8.decode(base64.decode(httpRequest['body'] as String)), '{"uid":"user-1"}');
      expect(httpRequest['oidcToken'], {
        'serviceAccountEmail': 'game-tasks@janggi-go.iam.gserviceaccount.com',
        'audience': 'https://game-abc-du.a.run.app',
      });
    });

    test('같은 taskId가 이미 있으면(409) 성공으로 본다', () async {
      final scheduler = CloudTasksScheduler(
        httpClient: MockClient((request) async => http.Response('{"error":{"status":"ALREADY_EXISTS"}}', 409)),
        projectId: 'janggi-go',
        environment: environment,
        logger: logger,
      );
      await scheduler.schedule(TaskName.devPing, {}, runAt: DateTime.utc(2026), taskId: 'same');
    });

    test('다른 실패는 오류로 던진다', () async {
      final scheduler = CloudTasksScheduler(
        httpClient: MockClient((request) async => http.Response('{}', 403)),
        projectId: 'janggi-go',
        environment: environment,
        logger: logger,
      );
      await expectLater(
        scheduler.schedule(TaskName.devPing, {}, runAt: DateTime.utc(2026)),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}
