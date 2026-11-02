import '../http/callable.dart';

// 엔드포인트의 `validateParams()`가 같이 쓰는 검사다. 검사 순서와 묶음은 각 `validateParams()`에 둔다.

/// RTDB 키와 Firestore 문서 ID로 쓸 수 있는 대국·방 ID. 대국 서버가 만드는 ID는 영문과 숫자 20자다.
final _gameIdPattern = RegExp(r'^[A-Za-z0-9]{1,64}$');

/// `data`가 객체인지 확인한다.
Map<String, Object?> requireParamsMap(Object? requestParams) {
  if (requestParams is! Map<String, Object?>) {
    throw const CallableException.invalidArgument('data는 객체여야 합니다');
  }
  return requestParams;
}

/// [key]의 대국 ID.
String requireGameId(Map<String, Object?> requestParams, String key) {
  final gameId = requestParams[key];
  if (gameId is! String || !_gameIdPattern.hasMatch(gameId)) {
    throw CallableException.invalidArgument('$key는 대국 ID여야 합니다');
  }
  return gameId;
}

/// [key]의 방 ID. 대국 서버가 만드는 방 ID는 영문과 숫자 20자다.
String requireRoomId(Map<String, Object?> requestParams, String key) {
  final roomId = requestParams[key];
  if (roomId is! String || !_gameIdPattern.hasMatch(roomId)) {
    throw CallableException.invalidArgument('$key는 방 ID여야 합니다');
  }
  return roomId;
}

/// [key]의 enum 값. [values]의 `name` 중 하나여야 한다.
T requireEnum<T extends Enum>(Map<String, Object?> requestParams, String key, List<T> values) {
  final name = requestParams[key];
  final value = name is String ? values.asNameMap()[name] : null;
  if (value == null) {
    throw CallableException.invalidArgument('$key는 ${values.map((value) => value.name).join(', ')} 중 하나여야 합니다');
  }
  return value;
}
