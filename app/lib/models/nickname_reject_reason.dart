/// 닉네임을 쓸 수 없는 이유. 서버의 `checkNickname` 응답과 `createProfile` 오류의 `details.code`로 받는다.
///
/// Functions의 `NicknameRejectReason`(`server/functions/src/models/nickname.ts`)과 값을 일치시킨다.
enum NicknameRejectReason {
  invalidFormat,
  taken,
  bannedWord,
  impersonation;

  /// 서버가 보낸 이름에 맞는 값. 모르는 값이면 null이다.
  static NicknameRejectReason? fromName(Object? name) => values.asNameMap()[name];
}

/// 닉네임을 쓸 수 있는지 서버가 답한 결과.
class NicknameAvailability {
  final bool available;

  /// 쓸 수 없는 이유. 쓸 수 있거나 앱이 모르는 이유면 null이다.
  final NicknameRejectReason? reason;

  const NicknameAvailability({required this.available, required this.reason});
}
