import '../l10n/app_localizations.dart';
import '../models/game_error_code.dart';
import '../models/nickname_reject_reason.dart';

/// 사용자에게 보여줄 오류의 종류.
enum AppErrorCode {
  /// 사용자가 로그인 창을 스스로 닫았다. 메시지를 보여주지 않는다.
  signInCanceled,
  invalidEmail,
  wrongEmailOrPassword,
  emailAlreadyInUse,
  weakPassword,
  tooManyRequests,
  network,
  nicknameInvalidFormat,
  nicknameTaken,
  nicknameBannedWord,
  nicknameImpersonation,
  gameNotFound,
  gameBusy,
  gameNotPlayer,
  gameNotYourTurn,
  gameIllegalMove,
  gameMoveConflict,
  gameOver,
  sanctioned,
  rematchUnavailable,
  roomFull,
  roomClosed,
  kicked,
  rankOutOfRange,
  notHost,
  challengeLimited,
  targetUnavailable,
}

/// 사용자에게 다국어 메시지로 보여줄 오류. 사용자용 오류는 이 클래스로만 표현한다.
class AppException implements Exception {
  final AppErrorCode code;

  const AppException(this.code);

  /// 서버가 닉네임을 거절한 이유에 맞는 오류.
  factory AppException.fromNicknameRejectReason(NicknameRejectReason reason) => AppException(switch (reason) {
    NicknameRejectReason.invalidFormat => AppErrorCode.nicknameInvalidFormat,
    NicknameRejectReason.taken => AppErrorCode.nicknameTaken,
    NicknameRejectReason.bannedWord => AppErrorCode.nicknameBannedWord,
    NicknameRejectReason.impersonation => AppErrorCode.nicknameImpersonation,
  });

  /// 대국 서버가 거절한 이유에 맞는 오류. 앱이 따로 알릴 것이 없는 이유면 null이고, 화면은 그 작업의 기본 오류 메시지를 보여준다.
  static AppException? fromGameErrorCode(GameErrorCode code) {
    final appCode = switch (code) {
      GameErrorCode.notFound => AppErrorCode.gameNotFound,
      GameErrorCode.busy => AppErrorCode.gameBusy,
      GameErrorCode.notPlayer => AppErrorCode.gameNotPlayer,
      GameErrorCode.notYourTurn => AppErrorCode.gameNotYourTurn,
      GameErrorCode.illegalMove => AppErrorCode.gameIllegalMove,
      GameErrorCode.moveConflict => AppErrorCode.gameMoveConflict,
      GameErrorCode.gameOver => AppErrorCode.gameOver,
      GameErrorCode.sanctioned => AppErrorCode.sanctioned,
      GameErrorCode.rematchUnavailable => AppErrorCode.rematchUnavailable,
      GameErrorCode.roomFull => AppErrorCode.roomFull,
      GameErrorCode.roomClosed => AppErrorCode.roomClosed,
      GameErrorCode.kicked => AppErrorCode.kicked,
      GameErrorCode.rankOutOfRange => AppErrorCode.rankOutOfRange,
      GameErrorCode.notHost => AppErrorCode.notHost,
      GameErrorCode.challengeLimited => AppErrorCode.challengeLimited,
      GameErrorCode.targetUnavailable => AppErrorCode.targetUnavailable,
      _ => null,
    };
    return appCode == null ? null : AppException(appCode);
  }

  String getMessage(AppLocalizations l10n) => switch (code) {
    // 로그인을 그만뒀어요
    AppErrorCode.signInCanceled => l10n.errorSignInCanceled,
    // 이메일 주소를 다시 확인해 주세요
    AppErrorCode.invalidEmail => l10n.errorInvalidEmail,
    // 이메일 또는 비밀번호가 맞지 않아요
    AppErrorCode.wrongEmailOrPassword => l10n.errorWrongEmailOrPassword,
    // 이미 가입한 이메일이에요. 로그인해 주세요
    AppErrorCode.emailAlreadyInUse => l10n.errorEmailAlreadyInUse,
    // 비밀번호는 6자 이상으로 정해 주세요
    AppErrorCode.weakPassword => l10n.errorWeakPassword,
    // 시도가 너무 많아요. 잠시 후 다시 해 주세요
    AppErrorCode.tooManyRequests => l10n.errorTooManyRequests,
    // 인터넷 연결을 확인해 주세요
    AppErrorCode.network => l10n.errorNetwork,
    // 한글, 영문, 숫자로 2~10자로 정해 주세요
    AppErrorCode.nicknameInvalidFormat => l10n.nicknameInvalidFormat,
    // 이미 다른 사람이 쓰고 있어요
    AppErrorCode.nicknameTaken => l10n.nicknameTaken,
    // 쓸 수 없는 말이 들어 있어요
    AppErrorCode.nicknameBannedWord => l10n.nicknameBannedWord,
    // 운영진으로 오해할 수 있는 이름은 쓸 수 없어요
    AppErrorCode.nicknameImpersonation => l10n.nicknameImpersonation,
    // 상대나 대국을 찾지 못했어요
    AppErrorCode.gameNotFound => l10n.errorGameNotFound,
    // 이미 대국이나 대기 중인 사람이 있어요
    AppErrorCode.gameBusy => l10n.errorGameBusy,
    // 이 대국의 대국자가 아니에요
    AppErrorCode.gameNotPlayer => l10n.errorGameNotPlayer,
    // 지금은 내 차례가 아니에요
    AppErrorCode.gameNotYourTurn => l10n.errorGameNotYourTurn,
    // 둘 수 없는 수예요
    AppErrorCode.gameIllegalMove => l10n.errorGameIllegalMove,
    // 판을 서버와 다시 맞췄어요
    AppErrorCode.gameMoveConflict => l10n.errorGameMoveConflict,
    // 이미 끝난 대국이에요
    AppErrorCode.gameOver => l10n.errorGameOver,
    // 이용이 제한되어 지금은 대국을 할 수 없어요
    AppErrorCode.sanctioned => l10n.errorSanctioned,
    // 지금은 다시 두기를 할 수 없어요
    AppErrorCode.rematchUnavailable => l10n.errorRematchUnavailable,
    // 방에 빈자리가 없어요
    AppErrorCode.roomFull => l10n.errorRoomFull,
    // 닫힌 방이에요
    AppErrorCode.roomClosed => l10n.errorRoomClosed,
    // 이 방에는 다시 들어갈 수 없어요
    AppErrorCode.kicked => l10n.errorKicked,
    // 이 방에 들어갈 수 있는 급수가 아니에요
    AppErrorCode.rankOutOfRange => l10n.errorRankOutOfRange,
    // 방장만 할 수 있어요
    AppErrorCode.notHost => l10n.errorNotHost,
    // 이 상대에게 여러 번 거절되어 잠시 신청할 수 없어요
    AppErrorCode.challengeLimited => l10n.errorChallengeLimited,
    // 상대가 지금은 신청을 받을 수 없어요
    AppErrorCode.targetUnavailable => l10n.errorTargetUnavailable,
  };
}
