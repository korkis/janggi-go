import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:janggigo_game/firebase/firestore_client.dart';
import 'package:test/test.dart';

void main() {
  const root = 'projects/p/databases/(default)/documents';

  /// 트랜잭션 요청을 기록하고 [commitStatuses] 순서대로 커밋에 답하는 가짜 Firestore.
  ({FirestoreClient client, List<String> calls, List<Duration> delays}) createClient(List<int> commitStatuses) {
    final calls = <String>[];
    final delays = <Duration>[];
    var transactionCount = 0;
    var commitCount = 0;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith(':beginTransaction')) {
        transactionCount++;
        final options = (jsonDecode(request.body) as Map)['options'] as Map;
        calls.add('begin ${(options['readWrite'] as Map)['retryTransaction'] ?? '-'}');
        return http.Response(jsonEncode({'transaction': 't$transactionCount'}), 200);
      }
      if (path.endsWith(':commit')) {
        final body = jsonDecode(request.body) as Map;
        calls.add('commit ${body['transaction']}');
        final status = commitStatuses[commitCount++];
        if (status == 200) {
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'error': {'code': status, 'status': 'ABORTED', 'message': 'contention'},
          }),
          status,
        );
      }
      if (path.endsWith(':rollback')) {
        calls.add('rollback ${(jsonDecode(request.body) as Map)['transaction']}');
        return http.Response('{}', 200);
      }
      expect(path, endsWith(':batchGet'));
      final body = jsonDecode(request.body) as Map;
      calls.add('get ${body['transaction']}');
      return http.Response(
        jsonEncode([
          {
            'found': {
              'name': '$root/games/g1',
              'fields': {
                'count': {'integerValue': '1'},
              },
            },
          },
          {'missing': '$root/games/g2'},
        ]),
        200,
      );
    });
    return (
      client: FirestoreClient(
        httpClient: client,
        baseUri: Uri.parse('http://firestore.test'),
        projectId: 'p',
        sleep: (delay) async => delays.add(delay),
      ),
      calls: calls,
      delays: delays,
    );
  }

  test('커밋이 ABORTED면 retryTransaction으로 처음부터 다시 실행한다', () async {
    final (:client, :calls, delays: _) = createClient([409, 200]);
    var runs = 0;

    final result = await client.runTransaction((transaction) async {
      runs++;
      final current = await transaction.get('games/g1');
      transaction.update('games/g1', {'count': (current!['count'] as int) + 1});
      return runs;
    });

    expect(result, 2);
    expect(calls, ['begin -', 'get t1', 'commit t1', 'begin t1', 'get t2', 'commit t2']);
  });

  test('트랜잭션에서 여러 문서를 한 번에 읽는다', () async {
    final (:client, :calls, :delays) = createClient([200]);
    final documents = await client.runTransaction((transaction) => transaction.getAll(['games/g1', 'games/g2']));
    expect(documents, {
      'games/g1': {'count': 1},
      'games/g2': null,
    });
    expect(calls, ['begin -', 'get t1', 'commit t1']);
    expect(delays, isEmpty);
  });

  test('maxAttempts번 모두 ABORTED면 오류를 던진다', () async {
    final (:client, :calls, delays: _) = createClient([409, 409]);
    await expectLater(
      client.runTransaction((transaction) async => transaction.set('games/g1', {}), maxAttempts: 2),
      throwsA(isA<FirestoreException>().having((error) => error.status, 'status', 'ABORTED')),
    );
    expect(calls.where((call) => call.startsWith('commit')), hasLength(2));
  });

  test('다시 실행하기 전에 상한을 두 배씩 늘린 무작위 시간을 기다린다', () async {
    final (:client, calls: _, :delays) = createClient([409, 409, 409, 200]);
    await client.runTransaction((transaction) async => transaction.set('games/g1', {}));
    expect(delays, hasLength(3));
    for (final (index, limitMs) in [200, 400, 800].indexed) {
      expect(delays[index].inMilliseconds, inInclusiveRange(0, limitMs));
    }
  });

  test('쓰기 뒤에 읽으면 오류로 본다', () async {
    final (:client, calls: _, delays: _) = createClient([200]);
    await expectLater(
      client.runTransaction((transaction) async {
        transaction.set('games/g1', {});
        await transaction.get('games/g2');
      }),
      throwsStateError,
    );
  });

  test('쓰기를 REST 형식으로 바꾼다', () async {
    late Map<String, Object?> sent;
    final client = FirestoreClient(
      httpClient: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response('{}', 200);
      }),
      baseUri: Uri.parse('http://firestore.test'),
      projectId: 'p',
    );

    await client.commit([
      const CreateWrite('users/u1', {'a': 1}),
      const UpdateWrite('users/u1', {'b': true, 'odd-name': null}),
      const DeleteWrite('users/u2'),
    ]);

    expect(sent['writes'], [
      {
        'update': {
          'name': '$root/users/u1',
          'fields': {
            'a': {'integerValue': '1'},
          },
        },
        'currentDocument': {'exists': false},
      },
      {
        'update': {
          'name': '$root/users/u1',
          'fields': {
            'b': {'booleanValue': true},
            'odd-name': {'nullValue': null},
          },
        },
        'updateMask': {
          'fieldPaths': ['b', '`odd-name`'],
        },
        'currentDocument': {'exists': true},
      },
      {'delete': '$root/users/u2'},
    ]);
  });
}
