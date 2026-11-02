import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'user_profile.g.dart';

/// Firestore `users/{uid}`. 다른 사용자에게도 보이는 공개 프로필이다.
///
/// 필드는 Functions의 `User`(`server/functions/src/models/user.ts`)와 일치시킨다.
@JsonSerializable(createToJson: false)
class UserProfile {
  final String nickname;

  /// 급수. 1이 18급, 18이 1급, 19가 1단, 27이 9단이다.
  final int rankLevel;
  final UserStats stats;

  @TimestampConverter()
  final DateTime createdAt;

  const UserProfile({required this.nickname, required this.rankLevel, required this.stats, required this.createdAt});

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
}

@JsonSerializable(createToJson: false)
class UserStats {
  final int games;
  final int wins;
  final int losses;

  const UserStats({required this.games, required this.wins, required this.losses});

  factory UserStats.fromJson(Map<String, dynamic> json) => _$UserStatsFromJson(json);
}
