// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  nickname: json['nickname'] as String,
  rankLevel: (json['rankLevel'] as num).toInt(),
  stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>),
  createdAt: const TimestampConverter().fromJson(
    json['createdAt'] as Timestamp,
  ),
);

UserStats _$UserStatsFromJson(Map<String, dynamic> json) => UserStats(
  games: (json['games'] as num).toInt(),
  wins: (json['wins'] as num).toInt(),
  losses: (json['losses'] as num).toInt(),
);
