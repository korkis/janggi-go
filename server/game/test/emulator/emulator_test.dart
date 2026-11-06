@Tags(['emulator'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:janggigo_game/endpoints/dev_ping_task.dart';
import 'package:janggigo_game/firebase/firestore_client.dart';
import 'package:janggigo_game/firebase/rtdb_client.dart';
import 'package:janggigo_game/game_server.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/server_environment.dart';
import 'package:test/test.dart';

/// Firebase Emulator Suite에 붙는 통합 테스트. `server/game/README.md`의 "테스트"처럼
/// `firebase emulators:exec`로 실행하면 돈다. 에뮬레이터 주소가 없으면 건너뛴다.
///
/// 다른 테스트나 앱이 같은 에뮬레이터를 쓰고 있을 수 있으므로 데이터를 지우지 않고 매번 새 ID를 쓴다.
void main() {
  final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final skip = emulatorHost == null ? 'FIRESTORE_EMULATOR_HOST가 없습니다. firebase emulators:exec로 실행하세요' : false;

  group('에뮬레이터', skip: skip, () {
    late GameServer server;
    late HttpServer httpServer;
    late StreamController<DevPingTaskParams> devPingTaskRuns;

    setUpAll(() async {
      devPingTaskRuns = StreamController.broadcast();
      server = GameServer.create(
        environment: ServerEnvironment.fromPlatform(),
        logger: GameLogger(format: LogFormat.text, minSeverity: LogSeverity.warning),
        onDevPingTask: devPingTaskRuns.add,
      );
      httpServer = await server.serve(port: 0);
    });

    tearDownAll(() async {
      await server.close();
      await devPingTaskRuns.close();
    });

    group('FirestoreClient', () {
      test('만들고 읽고 고치고 지운다', () async {
        final firestore = server.firestore;
        final path = 'emulator_test/${_randomId()}';
        final createdAt = DateTime.now().toUtc();

        await firestore.commit([
          CreateWrite(path, {
            'name': '장기',
            'count': 1,
            'createdAt': createdAt,
            'nested': {'a': true},
          }),
        ]);
        expect(await firestore.getDocument(path), {
          'name': '장기',
          'count': 1,
          'createdAt': createdAt,
          'nested': {'a': true},
        });

        await firestore.commit([
          UpdateWrite(path, {'count': 2}),
        ]);
        expect((await firestore.getDocument(path))?['count'], 2);
        expect((await firestore.getDocument(path))?['name'], '장기');

        await expectLater(
          firestore.commit([CreateWrite(path, {})]),
          throwsA(isA<FirestoreException>().having((error) => error.status, 'status', 'ALREADY_EXISTS')),
        );

        await firestore.commit([DeleteWrite(path)]);
        expect(await firestore.getDocument(path), isNull);
      });

      test('트랜잭션 안에서 읽고 쓴다', () async {
        final firestore = server.firestore;
        final path = 'emulator_test/${_randomId()}';
        await firestore.commit([
          SetWrite(path, {'count': 0}),
        ]);

        Future<int> increment() => firestore.runTransaction((transaction) async {
          final current = await transaction.get(path);
          final next = (current!['count'] as int) + 1;
          transaction.update(path, {'count': next});
          return next;
        });
        expect(await increment(), 1);
        expect(await increment(), 2);

        expect((await firestore.getDocument(path))?['count'], 2);
      });

      // 같은 문서를 동시에 바꾸는 트랜잭션은 여기서 확인하지 않는다. 에뮬레이터는 읽기 잠금이 엇갈리면 약 2초 뒤
      // `Transaction lock timeout`(ABORTED)으로 끝낸다. ABORTED 재시도는 test/firestore_client_test.dart에서 본다.

      test('트랜잭션에서 오류가 나면 쓰지 않는다', () async {
        final firestore = server.firestore;
        final path = 'emulator_test/${_randomId()}';
        await expectLater(
          firestore.runTransaction((transaction) async {
            transaction.set(path, {'written': true});
            throw StateError('중단');
          }),
          throwsStateError,
        );
        expect(await firestore.getDocument(path), isNull);
      });
    });

    group('RtdbClient', () {
      test('쓰고 읽고 얕게 읽고 지운다', () async {
        final rtdb = server.rtdb;
        final path = 'emulator_test/${_randomId()}';
        await rtdb.put(path, {
          'a': {'x': 1},
          'b': {'y': 2},
        });
        await rtdb.patch(path, {'a/x': 3});
        expect(await rtdb.get(path), {
          'a': {'x': 3},
          'b': {'y': 2},
        });
        expect(await rtdb.get(path, shallow: true), {'a': true, 'b': true});
        await rtdb.delete(path);
        expect(await rtdb.get(path), isNull);
      });

      test('ETag가 다르면 쓰지 않는다', () async {
        final rtdb = server.rtdb;
        final path = 'emulator_test/${_randomId()}';
        await rtdb.put(path, {'version': 1});
        final snapshot = await rtdb.getWithEtag(path);
        await rtdb.put(path, {'version': 2});

        await expectLater(
          rtdb.putIfMatch(path, {'version': 3}, snapshot.etag),
          throwsA(isA<RtdbEtagMismatch>().having((mismatch) => mismatch.current.value, 'current', {'version': 2})),
        );
        expect(await rtdb.get(path), {'version': 2});
        await rtdb.delete(path);
      });

      test('동시에 돈 runTransaction은 모두 반영된다', () async {
        final rtdb = server.rtdb;
        final path = 'emulator_test/${_randomId()}';
        Future<Object?> increment() => rtdb.runTransaction(path, (current) => ((current as int?) ?? 0) + 1);
        await Future.wait([for (var i = 0; i < 5; i++) increment()]);
        expect(await rtdb.get(path), 5);
        await rtdb.delete(path);
      });
    });

    group('devPing', () {
      final client = http.Client();
      tearDownAll(client.close);

      Future<http.Response> callDevPing(String idToken, Object? data) {
        return client.post(
          Uri.parse('http://127.0.0.1:${httpServer.port}/devPing'),
          headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
          body: jsonEncode({'data': data}),
        );
      }

      test('Auth 에뮬레이터 토큰으로 부르고 예약 작업까지 돈다', () async {
        final (:uid, :idToken) = await _signUp(client);

        final withoutProfile = await callDevPing(idToken, null);
        expect(withoutProfile.statusCode, 400);
        expect(jsonDecode(withoutProfile.body), {
          'error': {
            'status': 'FAILED_PRECONDITION',
            'message': isA<String>(),
            'details': {'code': 'profileRequired'},
          },
        });

        // 프로필은 Functions가 만든다. 여기서는 테스트 준비로 직접 쓴다.
        await server.firestore.commit([
          CreateWrite('users/$uid', {
            'nickname': '테스트$uid'.substring(0, 10),
            'rankLevel': 1,
            'stats': {'games': 0, 'wins': 0, 'losses': 0},
            'createdAt': DateTime.now().toUtc(),
          }),
        ]);

        final taskRun = devPingTaskRuns.stream.firstWhere((params) => params.uid == uid);
        final response = await callDevPing(idToken, {'taskDelaySeconds': 0});
        expect(response.statusCode, 200, reason: response.body);
        final result = (jsonDecode(response.body) as Map)['result'] as Map;
        expect(result['uid'], uid);
        expect(result['rankLevel'], 1);
        expect(result['taskScheduled'], true);

        final params = await taskRun.timeout(const Duration(seconds: 10));
        expect(params.requestedAt.millisecondsSinceEpoch, result['receivedAt']);
      });

      test('서명 없는 가짜 토큰이라도 다른 프로젝트 것이면 거절한다', () async {
        final payload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'iss': 'https://securetoken.google.com/janggi-go',
                  'aud': 'janggi-go',
                  'sub': 'someone',
                  'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  'auth_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                }),
              ),
            )
            .replaceAll('=', '');
        final response = await callDevPing('eyJhbGciOiJub25lIn0.$payload.', null);
        expect(response.statusCode, 401);
      });
    });
  });
}

/// Auth 에뮬레이터에 이메일 계정을 만들고 ID token을 받는다.
Future<({String uid, String idToken})> _signUp(http.Client client) async {
  final authHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] ?? '127.0.0.1:${EmulatorPorts.auth}';
  final response = await client.post(
    Uri.parse('http://$authHost/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': '${_randomId()}@example.com', 'password': 'password123', 'returnSecureToken': true}),
  );
  if (response.statusCode != 200) {
    throw StateError('Auth 에뮬레이터 가입 실패: ${response.statusCode} ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, Object?>;
  return (uid: body['localId'] as String, idToken: body['idToken'] as String);
}

String _randomId() {
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(20, (_) => characters[random.nextInt(characters.length)]).join();
}
