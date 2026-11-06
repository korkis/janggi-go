import 'package:json_annotation/json_annotation.dart';

part 'app_config.g.dart';

/// Firestore `configs/app`. 앱, Functions, 대국 서버가 같이 읽는 운영 설정이다.
///
/// 필드는 앱의 `AppConfig`(`app/lib/models/app_config.dart`), Functions의 `AppConfig`
/// (`server/functions/src/models/appConfig.ts`)와 일치시킨다. 필드 설명은 `docs/server.md`의 "configs/app"에 있다.
@JsonSerializable()
class AppConfig {
  /// 한 대국에서 끊겨 있어도 되는 시간 합계(초).
  final int disconnectLimitSeconds;

  /// 빠른 대국에서 같은 상대와 연달아 다시 둘 수 있는 횟수.
  final int quickRematchLimit;

  /// 대국실 접속자 탭과 방 대기실의 접속자 초대하기를 보여준다.
  final bool onlineUsersVisible;

  final bool autoSanctionEnabled;

  /// 대국 중 접속 상태의 `lastSeenAt`을 갱신하는 주기(초).
  final int heartbeatSeconds;

  /// 모든 대국의 참가비를 받는다. 끄면 새 대국부터 받지 않는다.
  final bool entryFeeEnabled;

  /// 가입 때 주는 엽전.
  final int coinSignupBonus;

  /// 대국 참가비.
  final int coinEntryFee;

  /// 대국이 끝났을 때 이긴 쪽의 보상.
  final int coinWinReward;

  /// 대국이 끝났을 때 진 쪽의 보상.
  final int coinLossReward;

  /// 하루 출석 엽전.
  final int coinAttendanceReward;

  /// 연속 7째 날의 출석 엽전. [coinAttendanceReward] 대신 준다.
  final int coinAttendanceStreakReward;

  /// 두 번째부터의 닉네임 변경 값.
  final int coinNicknameChangeCost;

  const AppConfig({
    required this.disconnectLimitSeconds,
    required this.quickRematchLimit,
    required this.onlineUsersVisible,
    required this.autoSanctionEnabled,
    required this.heartbeatSeconds,
    required this.entryFeeEnabled,
    required this.coinSignupBonus,
    required this.coinEntryFee,
    required this.coinWinReward,
    required this.coinLossReward,
    required this.coinAttendanceReward,
    required this.coinAttendanceStreakReward,
    required this.coinNicknameChangeCost,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);
}
