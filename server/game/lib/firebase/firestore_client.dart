import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'firestore_codec.dart';

/// Firestore REST API가 오류를 돌려줬다.
class FirestoreException implements Exception {
  final int statusCode;

  /// gRPC 상태 이름. 예: `ABORTED`, `ALREADY_EXISTS`, `NOT_FOUND`, `FAILED_PRECONDITION`.
  final String? status;
  final String message;

  const FirestoreException({required this.statusCode, required this.status, required this.message});

  @override
  String toString() => 'FirestoreException($statusCode $status): $message';
}

/// Firestore에 쓸 변경 하나. 문서 경로는 `users/abc`처럼 `documents` 아래 상대 경로다.
sealed class FirestoreWrite {
  final String path;

  const FirestoreWrite(this.path);
}

/// 문서 전체를 [data]로 바꾼다. 없으면 만든다.
class SetWrite extends FirestoreWrite {
  final Map<String, Object?> data;

  const SetWrite(super.path, this.data);
}

/// 문서가 없을 때만 만든다. 있으면 `ALREADY_EXISTS`로 실패한다.
class CreateWrite extends FirestoreWrite {
  final Map<String, Object?> data;

  const CreateWrite(super.path, this.data);
}

/// 있는 문서의 최상위 필드 중 [data]에 있는 것만 바꾼다. 문서가 없으면 `NOT_FOUND`로 실패한다.
class UpdateWrite extends FirestoreWrite {
  final Map<String, Object?> data;

  const UpdateWrite(super.path, this.data);
}

class DeleteWrite extends FirestoreWrite {
  const DeleteWrite(super.path);
}

/// 쿼리 조건의 비교 연산자. 값은 REST `FieldFilter.Operator` 이름이다.
enum QueryOperator {
  lessThan('LESS_THAN'),
  lessThanOrEqual('LESS_THAN_OR_EQUAL'),
  greaterThan('GREATER_THAN'),
  greaterThanOrEqual('GREATER_THAN_OR_EQUAL'),
  equal('EQUAL');

  final String wireName;

  const QueryOperator(this.wireName);
}

/// 쿼리 조건 하나. 여러 개를 주면 모두 맞아야 한다.
class QueryFilter {
  final String field;
  final QueryOperator operator;
  final Object? value;

  const QueryFilter(this.field, this.operator, this.value);
}

/// 쿼리 정렬 하나.
class QueryOrder {
  final String field;
  final bool descending;

  const QueryOrder(this.field, {this.descending = false});
}

/// 쿼리로 읽은 문서. [path]는 `documents` 아래 상대 경로다(예: `quick_queue/abc`).
class FirestoreDocument {
  final String path;
  final Map<String, Object?> data;

  const FirestoreDocument({required this.path, required this.data});

  /// 문서 ID. 경로의 마지막 부분이다.
  String get id => path.substring(path.lastIndexOf('/') + 1);
}

/// Firestore REST API(v1)의 얇은 클라이언트. repository만 쓴다(`docs/dev_rules.md`의 Dart 대국 서버 규칙).
///
/// Dart용 Firebase Admin SDK가 공식으로 없어서 REST를 직접 부른다(`docs/server.md`의 개발 환경).
class FirestoreClient {
  /// 인증 헤더를 붙이는 클라이언트(`AuthorizedClient`).
  final http.Client httpClient;

  /// `https://firestore.googleapis.com` 또는 에뮬레이터 주소.
  final Uri baseUri;
  final String projectId;

  /// [runTransaction]이 다시 실행하기 전에 기다린다. 테스트가 기다린 시간을 볼 때 바꾼다.
  final Future<void> Function(Duration delay) sleep;

  const FirestoreClient({
    required this.httpClient,
    required this.baseUri,
    required this.projectId,
    this.sleep = _sleep,
  });

  /// `projects/{p}/databases/(default)/documents`.
  String get documentsRoot => 'projects/$projectId/databases/(default)/documents';

  String getDocumentName(String path) => '$documentsRoot/$path';

  /// [path] 문서를 읽는다. 없으면 null.
  Future<Map<String, Object?>?> getDocument(String path) async {
    final response = await httpClient.get(_uri(getDocumentName(path)));
    if (response.statusCode == 404) {
      return null;
    }
    final body = _decodeResponse(response);
    return FirestoreCodec.decodeFields(body['fields'] as Map<String, Object?>?);
  }

  /// [paths] 문서들을 한 번에 읽는다. 결과는 경로별 데이터이고 없는 문서는 null이다.
  /// [transaction]을 주면 그 트랜잭션 안에서 읽는다.
  ///
  /// 트랜잭션 읽기는 `documents:batchGet`(POST)으로 한다. Firestore 에뮬레이터의 REST는 GET의 `transaction`
  /// 쿼리를 읽지 못하고 연결을 끊는다(`Unmapped JavaType: BYTE_STRING`).
  Future<Map<String, Map<String, Object?>?>> getDocuments(List<String> paths, {String? transaction}) async {
    final response = await httpClient.post(
      _uri('$documentsRoot:batchGet'),
      headers: _jsonHeaders,
      body: jsonEncode({'documents': paths.map(getDocumentName).toList(), 'transaction': ?transaction}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeResponse(response);
    }
    final prefix = '$documentsRoot/';
    final results = <String, Map<String, Object?>?>{for (final path in paths) path: null};
    // 응답은 문서마다 `found` 또는 `missing`이 있는 배열이다.
    for (final entry in jsonDecode(response.body) as List<Object?>) {
      final found = (entry as Map<String, Object?>)['found'];
      if (found is Map<String, Object?>) {
        final path = (found['name'] as String).substring(prefix.length);
        results[path] = FirestoreCodec.decodeFields(found['fields'] as Map<String, Object?>?);
      }
    }
    return results;
  }

  /// 최상위 [collection]에서 [filters]에 맞는 문서를 [orderBy] 순서로 [limit]개까지 읽는다.
  ///
  /// 트랜잭션 밖에서만 쓴다. 고를 문서는 트랜잭션에서 다시 읽어 확인한다.
  Future<List<FirestoreDocument>> runQuery(
    String collection, {
    List<QueryFilter> filters = const [],
    List<QueryOrder> orderBy = const [],
    int? limit,
  }) async {
    final fieldFilters = [
      for (final filter in filters)
        {
          'fieldFilter': {
            'field': {'fieldPath': _quoteFieldPath(filter.field)},
            'op': filter.operator.wireName,
            'value': FirestoreCodec.encodeValue(filter.value),
          },
        },
    ];
    final structuredQuery = <String, Object?>{
      'from': [
        {'collectionId': collection},
      ],
      if (fieldFilters.length == 1) 'where': fieldFilters.single,
      if (fieldFilters.length > 1)
        'where': {
          'compositeFilter': {'op': 'AND', 'filters': fieldFilters},
        },
      if (orderBy.isNotEmpty)
        'orderBy': [
          for (final order in orderBy)
            {
              'field': {'fieldPath': _quoteFieldPath(order.field)},
              'direction': order.descending ? 'DESCENDING' : 'ASCENDING',
            },
        ],
      'limit': ?limit,
    };
    final response = await httpClient.post(
      _uri('$documentsRoot:runQuery'),
      headers: _jsonHeaders,
      body: jsonEncode({'structuredQuery': structuredQuery}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeResponse(response);
    }
    final prefix = '$documentsRoot/';
    // 응답은 결과마다 `document`가 있는 배열이다. 결과가 없으면 `readTime`만 있는 항목 하나가 온다.
    return [
      for (final entry in jsonDecode(response.body) as List<Object?>)
        if ((entry as Map<String, Object?>)['document'] case final Map<String, Object?> document)
          FirestoreDocument(
            path: (document['name'] as String).substring(prefix.length),
            data: FirestoreCodec.decodeFields(document['fields'] as Map<String, Object?>?),
          ),
    ];
  }

  /// [writes]를 한꺼번에 적용한다. 하나라도 실패하면 모두 적용하지 않는다.
  Future<void> commit(List<FirestoreWrite> writes, {String? transaction}) async {
    final body = {'writes': writes.map(_encodeWrite).toList(), 'transaction': ?transaction};
    final response = await httpClient.post(
      _uri('$documentsRoot:commit'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    _decodeResponse(response);
  }

  /// [work]를 트랜잭션 안에서 실행하고 쓰기를 커밋한다.
  ///
  /// 다른 요청과 부딪혀 읽기나 커밋이 `ABORTED`로 실패하면 [maxAttempts]번까지 처음부터 다시 실행한다.
  /// 바로 다시 실행하면 부딪힌 요청들이 같은 순서로 또 부딪히므로 무작위 시간을 기다려 어긋나게 한다.
  /// [work]는 다시 실행될 수 있으므로 트랜잭션 밖에 부수 효과를 남기지 않는다.
  Future<T> runTransaction<T>(Future<T> Function(FirestoreTransaction transaction) work, {int maxAttempts = 5}) async {
    String? retryTransaction;
    for (var attempt = 1; ; attempt++) {
      final transactionId = await _beginTransaction(retryTransaction);
      final transaction = FirestoreTransaction._(this, transactionId);
      try {
        final result = await work(transaction);
        await commit(transaction._writes, transaction: transactionId);
        return result;
      } catch (error) {
        final aborted = transaction._readAborted || _isAborted(error);
        if (!aborted || attempt >= maxAttempts) {
          await _rollbackQuietly(transactionId);
          rethrow;
        }
        retryTransaction = transactionId;
      }
      await sleep(_getRetryDelay(attempt));
    }
  }

  static bool _isAborted(Object error) => error is FirestoreException && error.status == 'ABORTED';

  /// [attempt]번째 실패 뒤 기다릴 시간. 0부터 상한 사이의 무작위 값이고 상한은 재시도마다 두 배로 늘린다.
  static Duration _getRetryDelay(int attempt) {
    final maxMs = _retryBaseDelay.inMilliseconds * (1 << (attempt - 1));
    return Duration(milliseconds: _random.nextInt(maxMs + 1));
  }

  Future<String> _beginTransaction(String? retryTransaction) async {
    final options = <String, Object?>{
      'readWrite': {'retryTransaction': ?retryTransaction},
    };
    final response = await httpClient.post(
      _uri('$documentsRoot:beginTransaction'),
      headers: _jsonHeaders,
      body: jsonEncode({'options': options}),
    );
    return _decodeResponse(response)['transaction'] as String;
  }

  // 트랜잭션은 시간이 지나면 저절로 풀리므로 rollback 실패는 원래 오류를 가리지 않게 무시한다.
  Future<void> _rollbackQuietly(String transactionId) async {
    try {
      await httpClient.post(
        _uri('$documentsRoot:rollback'),
        headers: _jsonHeaders,
        body: jsonEncode({'transaction': transactionId}),
      );
    } on Object {
      return;
    }
  }

  Map<String, Object?> _encodeWrite(FirestoreWrite write) {
    final name = getDocumentName(write.path);
    switch (write) {
      case SetWrite(:final data):
        return {
          'update': {'name': name, 'fields': FirestoreCodec.encodeFields(data)},
        };
      case CreateWrite(:final data):
        return {
          'update': {'name': name, 'fields': FirestoreCodec.encodeFields(data)},
          'currentDocument': {'exists': false},
        };
      case UpdateWrite(:final data):
        return {
          'update': {'name': name, 'fields': FirestoreCodec.encodeFields(data)},
          'updateMask': {'fieldPaths': data.keys.map(_quoteFieldPath).toList()},
          'currentDocument': {'exists': true},
        };
      case DeleteWrite():
        return {'delete': name};
    }
  }

  Uri _uri(String resource, [Map<String, String>? queryParameters]) {
    return baseUri.replace(
      path: '/v1/$resource',
      queryParameters: queryParameters == null || queryParameters.isEmpty ? null : queryParameters,
    );
  }

  static Map<String, Object?> _decodeResponse(http.Response response) {
    final body = response.body.isEmpty ? <String, Object?>{} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body as Map<String, Object?>;
    }
    final error = body is Map<String, Object?> ? body['error'] : null;
    if (error is Map<String, Object?>) {
      throw FirestoreException(
        statusCode: response.statusCode,
        status: error['status'] as String?,
        message: error['message'] as String? ?? '',
      );
    }
    throw FirestoreException(statusCode: response.statusCode, status: null, message: response.body);
  }

  // 영문·숫자·밑줄이 아닌 글자가 있는 필드 이름은 백틱으로 감싼다.
  static String _quoteFieldPath(String field) {
    if (RegExp(r'^[A-Za-z_][A-Za-z_0-9]*$').hasMatch(field)) {
      return field;
    }
    return '`${field.replaceAll(r'\', r'\\').replaceAll('`', r'\`')}`';
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  // 첫 재시도 전에 기다리는 시간의 상한.
  static const _retryBaseDelay = Duration(milliseconds: 200);

  static final _random = Random();

  static Future<void> _sleep(Duration delay) => Future<void>.delayed(delay);
}

/// [FirestoreClient.runTransaction] 안에서 읽고 쓰기를 모은다. 쓰기는 [work]가 끝난 뒤 한꺼번에 커밋한다.
///
/// Firestore 트랜잭션은 모든 읽기가 쓰기보다 앞서야 하므로, 쓰기를 모으기 시작한 뒤 읽으면 오류로 본다.
class FirestoreTransaction {
  final FirestoreClient _client;
  final String id;
  final _writes = <FirestoreWrite>[];

  // 읽기가 `ABORTED`로 실패했는지. 병렬 읽기(`(a, b).wait`)의 오류는 `ParallelWaitError`로 감싸져 나가므로 여기서 기억한다.
  var _readAborted = false;

  FirestoreTransaction._(this._client, this.id);

  /// [path] 문서. 없으면 null.
  Future<Map<String, Object?>?> get(String path) async => (await getAll([path]))[path];

  /// [paths] 문서들을 한 번에 읽는다. 매칭처럼 여러 문서를 함께 볼 때 왕복을 줄인다.
  Future<Map<String, Map<String, Object?>?>> getAll(List<String> paths) async {
    if (_writes.isNotEmpty) {
      throw StateError('트랜잭션에서는 쓰기 전에 모두 읽어야 합니다: $paths');
    }
    try {
      return await _client.getDocuments(paths, transaction: id);
    } on FirestoreException catch (error) {
      // 병렬 읽기의 다른 실패가 지우지 않게 한 번 세우면 그대로 둔다.
      _readAborted = _readAborted || FirestoreClient._isAborted(error);
      rethrow;
    }
  }

  void set(String path, Map<String, Object?> data) => _writes.add(SetWrite(path, data));

  void create(String path, Map<String, Object?> data) => _writes.add(CreateWrite(path, data));

  void update(String path, Map<String, Object?> data) => _writes.add(UpdateWrite(path, data));

  void delete(String path) => _writes.add(DeleteWrite(path));
}
