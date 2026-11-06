import '../models/user.dart';

/// Callable 오류 상태. Firebase Functions Callable 프로토콜의 `error.status`와 HTTP 상태 코드다.
enum CallableStatus {
  invalidArgument('INVALID_ARGUMENT', 400),
  failedPrecondition('FAILED_PRECONDITION', 400),
  outOfRange('OUT_OF_RANGE', 400),
  unauthenticated('UNAUTHENTICATED', 401),
  permissionDenied('PERMISSION_DENIED', 403),
  notFound('NOT_FOUND', 404),
  alreadyExists('ALREADY_EXISTS', 409),
  aborted('ABORTED', 409),
  resourceExhausted('RESOURCE_EXHAUSTED', 429),
  internal('INTERNAL', 500),
  unimplemented('UNIMPLEMENTED', 501),
  unavailable('UNAVAILABLE', 503);

  final String wireName;
  final int httpStatus;

  const CallableStatus(this.wireName, this.httpStatus);
}

/// 앱이 다국어 메시지를 고르는 오류 코드(`docs/server.md`의 호출 방식). `error.details.code`에 `name`을 담는다.
///
/// 옛 앱은 모르는 코드를 기본 오류 메시지로 보여준다. 이미 배포한 코드의 이름은 바꾸지 않는다.
enum GameErrorCode {
  profileRequired,
  sanctioned,
  busy,
  notFound,
  roomFull,
  roomClosed,
  kicked,
  rankOutOfRange,
  notHost,
  notPlayer,
  notYourTurn,
  illegalMove,
  moveConflict,
  gameOver,
  challengeLimited,
  targetUnavailable,
  rematchUnavailable,
  extensionLimit,
  coinsInsufficient,
  opponentCoinsInsufficient,
  coinPriceChanged,
  featureDisabled,
}

/// 앱에 Callable 오류로 돌려줄 예외. 엔드포인트와 `validateParams()`가 던진다.
class CallableException implements Exception {
  final CallableStatus status;

  /// 개발자가 읽는 설명. 앱은 이 문구를 사용자에게 보여주지 않고 [code]로 메시지를 고른다.
  final String message;
  final GameErrorCode? code;

  const CallableException(this.status, this.message, {this.code});

  /// 파라미터가 잘못됐다. `validateParams()`가 쓴다.
  const CallableException.invalidArgument(this.message) : status = CallableStatus.invalidArgument, code = null;

  /// 지금 상태에서는 할 수 없다. [code]로 사유를 알린다.
  const CallableException.failedPrecondition(GameErrorCode this.code, this.message)
    : status = CallableStatus.failedPrecondition;

  /// 응답 본문 `{"error": {...}}`.
  Map<String, Object?> toResponseBody() => {
    'error': {
      'status': status.wireName,
      'message': message,
      if (code != null) 'details': {'code': code!.name},
    },
  };

  @override
  String toString() => 'CallableException(${status.wireName}, ${code?.name}): $message';
}

/// 로그인과 프로필 확인을 마친 Callable 요청.
class CallableRequest {
  final String uid;

  /// 호출자의 `users/{uid}`. 모든 대국 서버 API는 닉네임을 정한 사용자만 부른다(`docs/server.md`의 대국 서버 API).
  final User user;

  /// 서버가 요청을 받은 시각(UTC). 시계 계산은 이 시각을 기준으로 한다.
  final DateTime receivedAt;

  const CallableRequest({required this.uid, required this.user, required this.receivedAt});
}

/// 대국 서버 API 하나. `POST /{name}`으로 부른다.
///
/// [handle]은 먼저 `final requestParams = data;`로 받고, 파라미터가 있는 API는 비즈니스 로직 전에
/// 같은 파일의 `validateParams(requestParams)`를 부른다(`docs/dev_rules.md`의 Dart 대국 서버 규칙).
abstract class CallableEndpoint {
  /// API 이름이자 경로. 예: `playMove`.
  String get name;

  /// [data]는 요청 본문의 `data`다. 돌려준 값은 응답 본문의 `result`가 된다. JSON으로 바꿀 수 있어야 한다.
  Future<Object?> handle(CallableRequest request, Object? data);
}
