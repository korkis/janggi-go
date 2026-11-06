import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'user.g.dart';

/// Firestore `users/{uid}`. 다른 사용자에게도 보이는 공개 프로필이다.
///
/// 필드는 앱의 `UserProfile`(`app/lib/models/user_profile.dart`), Functions의 `User`(`server/functions/src/models/user.ts`)와
/// 일치시킨다. 닉네임은 Functions, 급수와 전적은 대국 서버가 쓴다(`docs/server.md`의 대국 서버와 Functions의 경계).
@JsonSerializable()
class User {
  final String nickname;

  /// 급수. 1이 18급, 18이 1급, 19가 1단, 27이 9단이다.
  final int rankLevel;
  final UserStats stats;

  @TimestampConverter()
  final DateTime createdAt;

  /// 회원 탈퇴를 누른 시각. 없으면 null이다(`docs/database.md`의 회원 탈퇴). 대국 서버는 이 사용자를 프로필이 없는 것으로 본다.
  @TimestampConverter()
  final DateTime? deletedAt;

  const User({
    required this.nickname,
    required this.rankLevel,
    required this.stats,
    required this.createdAt,
    this.deletedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@JsonSerializable()
class UserStats {
  final int games;
  final int wins;
  final int losses;

  const UserStats({required this.games, required this.wins, required this.losses});

  factory UserStats.fromJson(Map<String, dynamic> json) => _$UserStatsFromJson(json);
}
