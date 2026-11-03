import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'challenge_limit.g.dart';

/// Firestore `challenge_limits/{fromUid}_{toUid}`. 같은 상대에게 신청을 남발하지 못하게 하는 기록이다
/// (`docs/game/matching.md`의 로비와 신청). 서버 전용이라 대국 서버에만 선언한다.
@JsonSerializable(createToJson: true)
class ChallengeLimit {
  /// 거절되거나 응답을 받지 못한 연속 횟수. 수락되거나 제한이 걸리면 0으로 돌린다.
  final int failCount;

  /// 이 시각까지 이 상대에게 신청할 수 없다.
  @TimestampConverter()
  final DateTime? blockedUntil;

  @TimestampConverter()
  final DateTime updatedAt;

  const ChallengeLimit({required this.failCount, required this.blockedUntil, required this.updatedAt});

  factory ChallengeLimit.fromJson(Map<String, dynamic> json) => _$ChallengeLimitFromJson(json);

  Map<String, dynamic> toJson() => _$ChallengeLimitToJson(this);
}
