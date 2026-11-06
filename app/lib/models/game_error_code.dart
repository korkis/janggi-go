/// 대국 서버가 거절한 이유. 대국 서버 오류의 `details.code`로 받는다(`docs/server.md`의 호출 방식).
///
/// 대국 서버의 `GameErrorCode`(`server/game/lib/http/callable.dart`)와 값을 일치시킨다.
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
  gamesBlocked;

  /// 서버가 보낸 이름에 맞는 값. 모르는 값이면 null이다.
  static GameErrorCode? fromName(Object? name) => values.asNameMap()[name];
}
