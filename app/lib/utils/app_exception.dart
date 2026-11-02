import '../l10n/app_localizations.dart';
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
  };
}
