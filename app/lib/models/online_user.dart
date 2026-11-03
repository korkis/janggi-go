import 'package:json_annotation/json_annotation.dart';

import 'game_enums.dart';

part 'online_user.g.dart';

/// RTDB `online_users/{uid}`. 대국실 접속자 목록의 한 사람이다(`docs/database.md`).
///
/// 대국 서버가 쓰고 본인 앱은 지우거나 `challengesEnabled`만 바꾼다. 필드는 대국 서버의 `OnlineUser`
/// (`server/game/lib/models/online_user.dart`)와 일치시킨다.
@JsonSerializable(createToJson: false)
class OnlineUser {
  final String nickname;
  final int rankLevel;

  /// 모르는 값이면 null이다. 화면은 대국 중으로 본다.
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final OnlineStatus? status;

  /// 신청 받기. false면 "신청 받지 않음"으로 보여준다.
  final bool challengesEnabled;

  /// 들어온 시각(ms).
  final int since;

  const OnlineUser({
    required this.nickname,
    required this.rankLevel,
    required this.status,
    required this.challengesEnabled,
    required this.since,
  });

  factory OnlineUser.fromJson(Map<String, dynamic> json) => _$OnlineUserFromJson(json);
}
