import 'dart:convert';

import 'package:janggigo_game/firebase/firestore_codec.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/server_environment.dart';
import 'package:test/test.dart';

void main() {
  group('FirestoreCodec', () {
    test('Dart 값을 Firestore Value로 쓰고 다시 읽는다', () {
      final data = <String, Object?>{
        'none': null,
        'flag': true,
        'count': 9007199254740993,
        'ratio': 0.5,
        'name': '장기',
        'at': DateTime.utc(2026, 11, 2, 12, 30, 15, 123),
        'list': [1, 'a', null],
        'map': {
          'nested': {'deep': 1},
        },
        'empty': <Object?>[],
      };
      final encoded = FirestoreCodec.encodeFields(data);
      expect(encoded['count'], {'integerValue': '9007199254740993'});
      expect(encoded['at'], {'timestampValue': '2026-11-02T12:30:15.123Z'});
      expect(FirestoreCodec.decodeFields(jsonDecode(jsonEncode(encoded)) as Map<String, Object?>), data);
    });

    test('나노초 timestamp와 빈 배열·맵을 읽는다', () {
      final decoded = FirestoreCodec.decodeFields({
        'at': {'timestampValue': '2026-11-02T12:30:15.123456789Z'},
        'list': {'arrayValue': <String, Object?>{}},
        'map': {'mapValue': <String, Object?>{}},
      });
      expect(decoded['at'], DateTime.utc(2026, 11, 2, 12, 30, 15, 123, 456));
      expect((decoded['at'] as DateTime).isUtc, isTrue);
      expect(decoded['list'], isEmpty);
      expect(decoded['map'], isEmpty);
    });

    test('UTC가 아닌 시각은 쓰지 않는다', () {
      expect(() => FirestoreCodec.encodeValue(DateTime(2026)), throwsArgumentError);
    });
  });

  group('ServerEnvironment', () {
    test('기본은 에뮬레이터이고 firebase.json의 포트를 쓴다', () {
      final environment = ServerEnvironment.fromEnvironment({});
      expect(environment.mode, ServerMode.emulator);
      expect(environment.projectId, 'demo-janggi-go');
      expect(environment.port, 8090);
      expect(environment.firestoreBaseUri.toString(), 'http://127.0.0.1:8080');
      expect(environment.rtdbBaseUri.toString(), 'http://127.0.0.1:9000/?ns=janggi-go-default-rtdb');
      expect(environment.cloudTasks, isNull);
    });

    test('firebase emulators:exec가 넣은 주소를 쓴다', () {
      final environment = ServerEnvironment.fromEnvironment({
        'GCLOUD_PROJECT': 'demo-test',
        'FIRESTORE_EMULATOR_HOST': 'localhost:18080',
        'FIREBASE_DATABASE_EMULATOR_HOST': 'localhost:19000',
      });
      expect(environment.projectId, 'demo-test');
      expect(environment.firestoreBaseUri.toString(), 'http://localhost:18080');
      expect(environment.rtdbBaseUri.toString(), 'http://localhost:19000/?ns=janggi-go-default-rtdb');
    });

    test('에뮬레이터 모드는 demo 프로젝트만 쓴다', () {
      expect(() => ServerEnvironment.fromEnvironment({'GCLOUD_PROJECT': 'janggi-go'}), throwsStateError);
    });

    test('Cloud Run에서는 에뮬레이터 모드로 켜지지 않는다', () {
      expect(() => ServerEnvironment.fromEnvironment({'K_SERVICE': 'game'}), throwsStateError);
    });

    test('운영은 필요한 값이 모두 있어야 한다', () {
      final complete = {
        'GAME_ENV': 'production',
        'PORT': '8080',
        'GAME_SERVER_URL': 'https://game-abc-du.a.run.app',
        'TASKS_QUEUE': 'game-tasks',
        'TASKS_SERVICE_ACCOUNT': 'game-tasks@janggi-go.iam.gserviceaccount.com',
        'K_SERVICE': 'game',
      };
      final environment = ServerEnvironment.fromEnvironment(complete);
      expect(environment.mode, ServerMode.production);
      expect(environment.projectId, 'janggi-go');
      expect(environment.port, 8080);
      expect(environment.firestoreBaseUri.toString(), 'https://firestore.googleapis.com');
      expect(environment.rtdbBaseUri.toString(), 'https://janggi-go-default-rtdb.asia-southeast1.firebasedatabase.app');
      expect(environment.cloudTasks?.queue, 'game-tasks');

      for (final missing in ['PORT', 'GAME_SERVER_URL', 'TASKS_QUEUE', 'TASKS_SERVICE_ACCOUNT']) {
        expect(
          () => ServerEnvironment.fromEnvironment({...complete}..remove(missing)),
          throwsStateError,
          reason: missing,
        );
      }
    });

    test('모르는 GAME_ENV는 거절한다', () {
      expect(() => ServerEnvironment.fromEnvironment({'GAME_ENV': 'staging'}), throwsStateError);
    });
  });

  group('GameLogger', () {
    test('JSON 형식은 severity, message, trace를 담는다', () {
      final lines = <String>[];
      final logger = GameLogger(format: LogFormat.json, minSeverity: LogSeverity.info, write: lines.add);

      logger.debug('보이지 않는다');
      runWithTrace('projects/p/traces/abc', () => logger.info('devPing 성공', {'uid': 'user-1', 'at': null}));

      expect(lines, hasLength(1));
      expect(jsonDecode(lines.single), {
        'severity': 'INFO',
        'uid': 'user-1',
        'at': null,
        'message': 'devPing 성공',
        'logging.googleapis.com/trace': 'projects/p/traces/abc',
      });
    });

    test('getTraceName', () {
      expect(getTraceName('p', 'abc123/456;o=1'), 'projects/p/traces/abc123');
      expect(getTraceName('p', null), isNull);
    });
  });
}
