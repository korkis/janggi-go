import 'package:json_annotation/json_annotation.dart';

import 'game_enums.dart';

part 'online_user.g.dart';

/// RTDB `online_users/{uid}`. 대국실 접속자 목록의 한 사람이다(`docs/database.md`).
///
/// 대국 서버가 쓰고 본인 앱은 지우거나 `challengesEnabled`만 바꾼다. 필드는 앱의 `OnlineUser`(`app/lib/models/online_user.dart`)와
/// 일치시킨다. 닉네임과 급수는 앱이 쓰면 속일 수 있으므로 대국 서버가 `users`에서 옮겨 쓴다.
@JsonSerializable(createToJson: true)
class OnlineUser {
  final String nickname;
  final int rankLevel;
  final OnlineStatus status;

  /// 신청 받기. false면 "신청 받지 않음"으로 보여준다. 신청을 받을지는 대국 서버가 `users_private`로 판단한다.
  final bool challengesEnabled;

  /// 들어온 시각(밀리초).
  final int since;

  const OnlineUser({
    required this.nickname,
    required this.rankLevel,
    required this.status,
    required this.challengesEnabled,
    required this.since,
  });

  factory OnlineUser.fromJson(Map<String, dynamic> json) => _$OnlineUserFromJson(json);

  Map<String, dynamic> toJson() => _$OnlineUserToJson(this);
}
