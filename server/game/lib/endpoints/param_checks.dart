import 'package:janggi_core/janggi_core.dart';

import '../http/callable.dart';
import '../models/game_enums.dart';
import '../models/room.dart';

// 엔드포인트의 `validateParams()`가 같이 쓰는 검사다. 검사 순서와 묶음은 각 `validateParams()`에 둔다.

/// RTDB 키와 Firestore 문서 ID로 쓸 수 있는 대국·방 ID. 대국 서버가 만드는 ID는 영문과 숫자 20자다.
final _gameIdPattern = RegExp(r'^[A-Za-z0-9]{1,64}$');

/// Firebase Auth uid. 구글·애플·이메일 로그인의 uid는 영문과 숫자다.
final _uidPattern = RegExp(r'^[A-Za-z0-9]{1,128}$');

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

/// [key]의 신청 ID. 대국 서버가 만드는 신청 ID는 영문과 숫자 20자다.
String requireChallengeId(Map<String, Object?> requestParams, String key) {
  final challengeId = requestParams[key];
  if (challengeId is! String || !_gameIdPattern.hasMatch(challengeId)) {
    throw CallableException.invalidArgument('$key는 신청 ID여야 합니다');
  }
  return challengeId;
}

/// [key]의 사용자 uid.
String requireUid(Map<String, Object?> requestParams, String key) {
  final uid = requestParams[key];
  if (uid is! String || !_uidPattern.hasMatch(uid)) {
    throw CallableException.invalidArgument('$key는 사용자 uid여야 합니다');
  }
  return uid;
}

/// 접장기 조건 `{remover: HandicapRemover, pieces: 서로 다른 HandicapPiece 1개 이상}`. 방 만들기와 신청이 같이 쓴다.
RoomHandicap requireHandicap(Map<String, Object?> params) {
  final remover = requireEnum(params, 'remover', HandicapRemover.values);
  final names = params['pieces'];
  if (names is! List<Object?> || names.isEmpty) {
    throw const CallableException.invalidArgument('handicap.pieces는 기물 이름 목록이어야 합니다');
  }
  final pieces = <HandicapPiece>[];
  for (final name in names) {
    final piece = name is String ? HandicapPiece.values.asNameMap()[name] : null;
    if (piece == null || pieces.contains(piece)) {
      throw const CallableException.invalidArgument('handicap.pieces는 서로 다른 HandicapPiece여야 합니다');
    }
    pieces.add(piece);
  }
  return RoomHandicap(remover: remover, pieces: pieces);
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
