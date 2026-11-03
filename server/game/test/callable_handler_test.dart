import 'dart:convert';

import 'package:janggigo_game/auth/id_token_verifier.dart';
import 'package:janggigo_game/endpoints/dev_ping.dart';
import 'package:janggigo_game/firebase/firestore_client.dart';
import 'package:janggigo_game/http/callable.dart';
import 'package:janggigo_game/http/callable_handler.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/models/user.dart';
import 'package:janggigo_game/repositories/users_repository.dart';
import 'package:janggigo_game/tasks/task_scheduler.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/jwt_helpers.dart';

void main() {
  const projectId = 'demo-janggi-go';
  final now = DateTime.utc(2026, 11, 2, 12);
  final verifier = FirebaseIdTokenVerifier.emulator(projectId: projectId, clock: () => now);
  final logger = GameLogger(format: LogFormat.text, minSeverity: LogSeverity.error, write: (_) {});
  final user = User(
    nickname: '장기고수',
    rankLevel: 1,
    stats: const UserStats(games: 0, wins: 0, losses: 0),
    createdAt: now,
  );

  String tokenFor(String uid) => createUnsignedToken({
    'iss': 'https://securetoken.google.com/$projectId',
    'aud': projectId,
    'sub': uid,
    'iat': toSeconds(now),
    'auth_time': toSeconds(now),
    'exp': toSeconds(now.add(const Duration(hours: 1))),
  });

  Handler createHandler(CallableEndpoint endpoint, {Map<String, User> users = const {}}) {
    return createCallableHandler(
      endpoint: endpoint,
      idTokenVerifier: verifier,
      usersRepository: _FakeUsersRepository(users),
      logger: logger,
      clock: () => now,
    );
  }

  Request callRequest(Object? body, {String? token, String method = 'POST', String contentType = 'application/json'}) {
    return Request(
      method,
      Uri.parse('http://localhost/devPing'),
      headers: {'Content-Type': contentType, 'Authorization': ?token == null ? null : 'Bearer $token'},
      body: body is String ? body : jsonEncode(body),
    );
  }

  Future<(int, Map<String, Object?>)> call(Handler handler, Request request) async {
    final response = await handler(request);
    expect(response.headers['content-type'], startsWith('application/json'));
    return (response.statusCode, jsonDecode(await response.readAsString()) as Map<String, Object?>);
  }

  group('createCallableHandler', () {
    test('성공하면 {"result": ...}를 돌려준다', () async {
      final scheduler = _RecordingTaskScheduler();
      final handler = createHandler(
        DevPingEndpoint(taskScheduler: scheduler, logger: logger),
        users: {'user-1': user},
      );

      final (status, body) = await call(
        handler,
        callRequest({
          'data': {'taskDelaySeconds': 5},
        }, token: tokenFor('user-1')),
      );

      expect(status, 200);
      expect(body['result'], {
        'uid': 'user-1',
        'nickname': '장기고수',
        'rankLevel': 1,
        'receivedAt': now.millisecondsSinceEpoch,
        'taskScheduled': true,
      });
      expect(scheduler.scheduled.single.task, TaskName.devPing);
      expect(scheduler.scheduled.single.runAt, now.add(const Duration(seconds: 5)));
    });

    test('안드로이드 Functions SDK가 감싸 보낸 정수를 풀어서 넘긴다', () async {
      final scheduler = _RecordingTaskScheduler();
      final handler = createHandler(
        DevPingEndpoint(taskScheduler: scheduler, logger: logger),
        users: {'user-1': user},
      );
      final (status, body) = await call(
        handler,
        callRequest({
          'data': {
            'taskDelaySeconds': {'@type': 'type.googleapis.com/google.protobuf.Int64Value', 'value': '5'},
          },
        }, token: tokenFor('user-1')),
      );
      expect(status, 200, reason: '$body');
      expect(scheduler.scheduled.single.runAt, now.add(const Duration(seconds: 5)));
    });

    test('data가 null인 호출을 받는다', () async {
      final handler = createHandler(
        DevPingEndpoint(taskScheduler: _RecordingTaskScheduler(), logger: logger),
        users: {'user-1': user},
      );
      final (status, body) = await call(handler, callRequest({'data': null}, token: tokenFor('user-1')));
      expect(status, 200);
      expect((body['result'] as Map)['taskScheduled'], false);
    });

    test('토큰이 없으면 UNAUTHENTICATED', () async {
      final handler = createHandler(_ThrowingEndpoint(StateError('부르면 안 됩니다')));
      final (status, body) = await call(handler, callRequest({'data': null}));
      expect(status, 401);
      expect((body['error'] as Map)['status'], 'UNAUTHENTICATED');
    });

    test('토큰이 틀리면 UNAUTHENTICATED', () async {
      final handler = createHandler(_ThrowingEndpoint(StateError('부르면 안 됩니다')));
      final (status, body) = await call(handler, callRequest({'data': null}, token: 'broken'));
      expect(status, 401);
      expect((body['error'] as Map)['status'], 'UNAUTHENTICATED');
    });

    test('프로필이 없으면 FAILED_PRECONDITION과 profileRequired', () async {
      final handler = createHandler(_ThrowingEndpoint(StateError('부르면 안 됩니다')));
      final (status, body) = await call(handler, callRequest({'data': null}, token: tokenFor('user-1')));
      expect(status, 400);
      expect(body['error'], {
        'status': 'FAILED_PRECONDITION',
        'message': isA<String>(),
        'details': {'code': 'profileRequired'},
      });
    });

    test('validateParams()가 거절하면 INVALID_ARGUMENT', () async {
      final scheduler = _RecordingTaskScheduler();
      final handler = createHandler(
        DevPingEndpoint(taskScheduler: scheduler, logger: logger),
        users: {'user-1': user},
      );
      for (final data in [
        'text',
        {'taskDelaySeconds': -1},
        {'taskDelaySeconds': 61},
        {'taskDelaySeconds': 1.5},
      ]) {
        final (status, body) = await call(handler, callRequest({'data': data}, token: tokenFor('user-1')));
        expect(status, 400, reason: '$data');
        expect((body['error'] as Map)['status'], 'INVALID_ARGUMENT', reason: '$data');
      }
      expect(scheduler.scheduled, isEmpty);
    });

    test('본문이 Callable 모양이 아니면 INVALID_ARGUMENT', () async {
      final handler = createHandler(_ThrowingEndpoint(StateError('부르면 안 됩니다')), users: {'user-1': user});
      final token = tokenFor('user-1');
      for (final request in [
        callRequest({'notData': 1}, token: token),
        callRequest('{broken', token: token),
        callRequest({'data': null}, token: token, contentType: 'text/plain'),
        callRequest({'data': null}, token: token, method: 'PUT'),
      ]) {
        final (status, body) = await call(handler, request);
        expect(status, 400);
        expect((body['error'] as Map)['status'], 'INVALID_ARGUMENT');
      }
    });

    test('엔드포인트의 CallableException은 오류 코드와 함께 돌려준다', () async {
      final handler = createHandler(
        _ThrowingEndpoint(const CallableException.failedPrecondition(GameErrorCode.notYourTurn, '내 차례가 아닙니다')),
        users: {'user-1': user},
      );
      final (status, body) = await call(handler, callRequest({'data': null}, token: tokenFor('user-1')));
      expect(status, 400);
      expect(body['error'], {
        'status': 'FAILED_PRECONDITION',
        'message': '내 차례가 아닙니다',
        'details': {'code': 'notYourTurn'},
      });
    });

    test('예상하지 못한 오류는 내용을 숨기고 INTERNAL', () async {
      final handler = createHandler(_ThrowingEndpoint(StateError('비밀 내용')), users: {'user-1': user});
      final (status, body) = await call(handler, callRequest({'data': null}, token: tokenFor('user-1')));
      expect(status, 500);
      expect(body['error'], {'status': 'INTERNAL', 'message': 'INTERNAL'});
    });
  });

  test('decodeCallableValue는 중첩된 감싼 정수도 풀고 나머지는 그대로 둔다', () {
    const int64 = 'type.googleapis.com/google.protobuf.Int64Value';
    expect(
      decodeCallableValue({
        'a': {'@type': int64, 'value': '-3'},
        'b': [
          {'@type': 'type.googleapis.com/google.protobuf.UInt64Value', 'value': '7'},
          'x',
        ],
        'c': {'@type': 'other', 'value': '1'},
        'd': 1.5,
      }),
      {
        'a': -3,
        'b': [7, 'x'],
        'c': {'@type': 'other', 'value': '1'},
        'd': 1.5,
      },
    );
    expect(() => decodeCallableValue({'@type': int64, 'value': 'abc'}), throwsA(isA<CallableException>()));
  });

  test('getBearerToken', () {
    Request withAuthorization(String? value) =>
        Request('POST', Uri.parse('http://localhost/'), headers: {'Authorization': ?value});
    expect(getBearerToken(withAuthorization('Bearer abc.def.')), 'abc.def.');
    expect(getBearerToken(withAuthorization('bearer abc')), 'abc');
    expect(getBearerToken(withAuthorization('Basic abc')), isNull);
    expect(getBearerToken(withAuthorization(null)), isNull);
  });
}

class _FakeUsersRepository implements UsersRepository {
  final Map<String, User> users;

  _FakeUsersRepository(this.users);

  @override
  FirestoreClient get firestore => throw UnimplementedError();

  @override
  Future<User?> getUser(String uid) async => users[uid];

  @override
  Future<Map<String, User?>> getUsers(List<String> uids) async => {for (final uid in uids) uid: users[uid]};

  @override
  void updateRankLevelInTransaction(FirestoreTransaction transaction, String uid, int rankLevel) {
    throw UnimplementedError();
  }
}

class _ThrowingEndpoint extends CallableEndpoint {
  final Object error;

  _ThrowingEndpoint(this.error);

  @override
  String get name => 'throwing';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async => throw error;
}

class _RecordingTaskScheduler implements TaskScheduler {
  final scheduled = <({TaskName task, Map<String, Object?> payload, DateTime runAt, String? taskId})>[];

  @override
  Future<void> schedule(TaskName task, Map<String, Object?> payload, {required DateTime runAt, String? taskId}) async {
    scheduled.add((task: task, payload: payload, runAt: runAt, taskId: taskId));
  }
}
