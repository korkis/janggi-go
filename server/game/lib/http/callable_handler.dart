import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../auth/id_token_verifier.dart';
import '../auth/jwt.dart';
import '../clock.dart';
import '../logging.dart';
import '../repositories/users_repository.dart';
import 'callable.dart';

/// Firebase Functions Callable과 같은 프로토콜로 [endpoint]를 부르는 shelf 핸들러를 만든다(`docs/server.md`의 호출 방식).
///
/// 요청 `POST /{name}`, 본문 `{"data": ...}`, `Authorization: Bearer <Firebase ID token>`.
/// 성공하면 `{"result": ...}`, 실패하면 `{"error": {"status", "message", "details": {"code"}}}`를 돌려준다.
/// 앱은 Flutter `httpsCallableFromUrl`로 부른다.
Handler createCallableHandler({
  required CallableEndpoint endpoint,
  required FirebaseIdTokenVerifier idTokenVerifier,
  required UsersRepository usersRepository,
  required GameLogger logger,
  Clock clock = utcNow,
}) {
  return (Request httpRequest) async {
    final receivedAt = clock();
    String? uid;
    try {
      final data = await _readData(httpRequest);
      uid = await _verifyCaller(httpRequest, idTokenVerifier);
      final user = await usersRepository.getUser(uid);
      if (user == null) {
        throw const CallableException.failedPrecondition(GameErrorCode.profileRequired, '닉네임을 먼저 정해야 합니다');
      }
      logger.debug('callable 시작', {'api': endpoint.name, 'uid': uid});
      final result = await endpoint.handle(CallableRequest(uid: uid, user: user, receivedAt: receivedAt), data);
      return _jsonResponse(200, {'result': result});
    } on CallableException catch (error) {
      logger.info('callable 거절', {
        'api': endpoint.name,
        'uid': uid,
        'status': error.status.wireName,
        'code': error.code?.name,
        'message': error.message,
      });
      return _jsonResponse(error.status.httpStatus, error.toResponseBody());
    } catch (error, stackTrace) {
      logger.error('callable 실패', fields: {'api': endpoint.name, 'uid': uid}, error: error, stackTrace: stackTrace);
      // 내부 오류 내용은 앱에 보내지 않는다.
      const internal = CallableException(CallableStatus.internal, 'INTERNAL');
      return _jsonResponse(internal.status.httpStatus, internal.toResponseBody());
    }
  };
}

/// 본문 `{"data": ...}`의 `data`.
Future<Object?> _readData(Request httpRequest) async {
  if (httpRequest.method != 'POST') {
    throw const CallableException.invalidArgument('POST만 받습니다');
  }
  if (httpRequest.mimeType != 'application/json') {
    throw const CallableException.invalidArgument('Content-Type은 application/json이어야 합니다');
  }
  final Object? body;
  try {
    body = jsonDecode(await httpRequest.readAsString());
  } on FormatException {
    throw const CallableException.invalidArgument('본문이 JSON이 아닙니다');
  }
  if (body is! Map<String, Object?> || !body.containsKey('data')) {
    throw const CallableException.invalidArgument('본문에 data가 없습니다');
  }
  return decodeCallableValue(body['data']);
}

/// Callable 규약이 감싸 보내는 값을 푼다. 안드로이드 Functions SDK는 Java `Long`인 정수를
/// `{"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "1"}`처럼 문자열로 감싸 보내고, Firebase Functions
/// 서버는 이것을 숫자로 바꿔 넘긴다. 대국 서버도 같은 프로토콜을 받으므로 `validateParams()` 전에 같은 일을 한다.
Object? decodeCallableValue(Object? value) {
  if (value is List<Object?>) {
    return [for (final item in value) decodeCallableValue(item)];
  }
  if (value is! Map<String, Object?>) {
    return value;
  }
  final type = value['@type'];
  final wrapped = value['value'];
  if (value.length == 2 && (type == _int64ValueType || type == _uint64ValueType) && wrapped is String) {
    final number = int.tryParse(wrapped);
    if (number == null) {
      throw const CallableException.invalidArgument('정수 값을 읽지 못했습니다');
    }
    return number;
  }
  return {for (final MapEntry(:key, :value) in value.entries) key: decodeCallableValue(value)};
}

const _int64ValueType = 'type.googleapis.com/google.protobuf.Int64Value';
const _uint64ValueType = 'type.googleapis.com/google.protobuf.UInt64Value';

/// 호출자의 uid. ID token이 없거나 검사를 통과하지 못하면 `UNAUTHENTICATED`.
Future<String> _verifyCaller(Request httpRequest, FirebaseIdTokenVerifier idTokenVerifier) async {
  final token = getBearerToken(httpRequest);
  if (token == null) {
    throw const CallableException(CallableStatus.unauthenticated, '로그인이 필요합니다');
  }
  try {
    final verified = await idTokenVerifier.verify(token);
    return verified.uid;
  } on AuthException catch (error) {
    throw CallableException(CallableStatus.unauthenticated, error.message);
  }
}

/// `Authorization: Bearer <token>`의 토큰. 없으면 null.
String? getBearerToken(Request httpRequest) {
  final header = httpRequest.headers['authorization'];
  if (header == null) {
    return null;
  }
  final match = RegExp(r'^Bearer\s+(\S+)$', caseSensitive: false).firstMatch(header);
  return match?.group(1);
}

Response _jsonResponse(int statusCode, Object body) {
  return Response(statusCode, body: jsonEncode(body), headers: {'Content-Type': 'application/json; charset=utf-8'});
}
