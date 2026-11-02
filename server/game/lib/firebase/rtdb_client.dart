import 'dart:convert';

import 'package:http/http.dart' as http;

/// Realtime Database REST API가 오류를 돌려줬다.
class RtdbException implements Exception {
  final int statusCode;
  final String message;

  const RtdbException({required this.statusCode, required this.message});

  @override
  String toString() => 'RtdbException($statusCode): $message';
}

/// 값과 그 값을 읽었을 때의 ETag.
class RtdbSnapshot {
  /// 없으면 null.
  final Object? value;
  final String etag;

  const RtdbSnapshot({required this.value, required this.etag});
}

/// [RtdbClient.runTransaction]의 변환 함수가 쓰지 않고 끝내려고 던진다.
class RtdbTransactionAbort implements Exception {
  const RtdbTransactionAbort();
}

/// Realtime Database REST API의 얇은 클라이언트. repository만 쓴다(`docs/dev_rules.md`의 Dart 대국 서버 규칙).
class RtdbClient {
  /// 인증 헤더를 붙이는 클라이언트(`AuthorizedClient`).
  final http.Client httpClient;

  /// 인스턴스 주소. 에뮬레이터면 `?ns=<인스턴스>`가 붙어 있다.
  final Uri baseUri;

  const RtdbClient({required this.httpClient, required this.baseUri});

  /// [path]의 값. 없으면 null. [shallow]면 자식 값 대신 자식 키마다 `true`를 받는다(관전자 수 세기).
  Future<Object?> get(String path, {bool shallow = false}) async {
    final response = await httpClient.get(_uri(path, {if (shallow) 'shallow': 'true'}));
    return _decode(response);
  }

  /// [path]의 값과 ETag.
  Future<RtdbSnapshot> getWithEtag(String path) async {
    final response = await httpClient.get(_uri(path), headers: {'X-Firebase-ETag': 'true'});
    return RtdbSnapshot(value: _decode(response), etag: _getEtag(response));
  }

  /// [path]를 [value]로 바꾼다. null이면 지운다.
  Future<void> put(String path, Object? value) async {
    final response = await httpClient.put(_uri(path, _silent), headers: _jsonHeaders, body: jsonEncode(value));
    _decode(response);
  }

  /// [path] 아래의 [values] 자식만 바꾼다. 키에 `a/b` 같은 경로를 쓸 수 있다.
  Future<void> patch(String path, Map<String, Object?> values) async {
    final response = await httpClient.patch(_uri(path, _silent), headers: _jsonHeaders, body: jsonEncode(values));
    _decode(response);
  }

  Future<void> delete(String path) async {
    final response = await httpClient.delete(_uri(path, _silent));
    _decode(response);
  }

  /// [path]의 지금 값이 [etag]일 때만 [value]로 바꾼다. 그사이 다른 요청이 썼으면 [RtdbEtagMismatch]를 던진다.
  Future<void> putIfMatch(String path, Object? value, String etag) async {
    final response = await httpClient.put(
      _uri(path),
      headers: {..._jsonHeaders, 'if-match': etag},
      body: jsonEncode(value),
    );
    if (response.statusCode == 412) {
      throw RtdbEtagMismatch(RtdbSnapshot(value: jsonDecode(response.body), etag: _getEtag(response)));
    }
    _decode(response);
  }

  /// [path] 값을 [transform] 결과로 바꾼다. 다른 요청이 먼저 썼으면 새 값으로 [transform]을 다시 부른다.
  ///
  /// `docs/server.md`의 동시에 들어온 요청: 한 대국의 변경은 노드 전체를 ETag 조건부 쓰기로 바꾼다.
  /// [transform]이 [RtdbTransactionAbort]를 던지면 쓰지 않고 null을 돌려준다. 다른 예외는 그대로 나간다.
  Future<Object?> runTransaction(
    String path,
    Object? Function(Object? current) transform, {
    int maxAttempts = 10,
  }) async {
    var snapshot = await getWithEtag(path);
    for (var attempt = 1; ; attempt++) {
      final Object? next;
      try {
        next = transform(snapshot.value);
      } on RtdbTransactionAbort {
        return null;
      }
      try {
        await putIfMatch(path, next, snapshot.etag);
        return next;
      } on RtdbEtagMismatch catch (mismatch) {
        if (attempt >= maxAttempts) {
          rethrow;
        }
        snapshot = mismatch.current;
      }
    }
  }

  Uri _uri(String path, [Map<String, String> queryParameters = const {}]) {
    final query = {...baseUri.queryParameters, ...queryParameters};
    return baseUri.replace(path: '/$path.json', queryParameters: query.isEmpty ? null : query);
  }

  static Object? _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RtdbException(statusCode: response.statusCode, message: response.body);
    }
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }

  static String _getEtag(http.Response response) {
    final etag = response.headers['etag'];
    if (etag == null) {
      throw RtdbException(statusCode: response.statusCode, message: 'ETag가 없습니다');
    }
    return etag;
  }

  // 쓰기 응답 본문을 받지 않는다. 응답은 204가 된다.
  static const _silent = {'print': 'silent'};

  static const _jsonHeaders = {'Content-Type': 'application/json'};
}

/// [RtdbClient.putIfMatch]에서 ETag가 달랐다. [current]는 지금 값이다.
class RtdbEtagMismatch implements Exception {
  final RtdbSnapshot current;

  const RtdbEtagMismatch(this.current);
}
