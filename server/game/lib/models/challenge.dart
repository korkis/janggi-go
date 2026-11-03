import 'package:json_annotation/json_annotation.dart';

import 'active_game.dart';
import 'game_enums.dart';
import 'room.dart';
import 'timestamp_converter.dart';

part 'challenge.g.dart';

/// Firestore `challenges/{challengeId}`. 대국 신청이다(`docs/database.md`). 보내는 사람과 받는 사람 모두 한 번에 하나만 가진다.
///
/// 대국 서버만 쓴다. 필드는 앱의 `Challenge`(`app/lib/models/challenge.dart`)와 일치시킨다.
@JsonSerializable(createToJson: true, explicitToJson: true)
class Challenge {
  final String fromUid;

  /// 수락 팝업 표시용 신청한 사람의 닉네임과 급수. 모양이 방의 방장 정보와 같아 [RoomPlayer]를 쓴다.
  final RoomPlayer from;
  final String toUid;

  /// 방 대기실의 접속자 초대면 그 방. 수락하면 방에 들어간다.
  final String? roomId;

  /// 신청한 사람의 진영. 접장기면 떼는 쪽이 한이므로 쓰지 않는다. 방 초대면 방장의 진영이다.
  final SideChoice? senderSide;

  /// 접장기 조건. `remover`는 신청한 사람 기준이다. 모양이 방의 접장기와 같아 [RoomHandicap]을 쓴다.
  final RoomHandicap? handicap;

  /// 수락하면 둘 대국의 시간 규칙. 수락 팝업의 조건 칩에 쓴다.
  final TimeControl timeControl;
  final ChallengeStatus status;

  /// 응답 마감. 팝업의 남은 시간 막대에 쓴다.
  @TimestampConverter()
  final DateTime expiresAt;

  /// 수락해서 만든 대국.
  final String? gameId;

  @TimestampConverter()
  final DateTime createdAt;

  @TimestampConverter()
  final DateTime updatedAt;

  const Challenge({
    required this.fromUid,
    required this.from,
    required this.toUid,
    required this.roomId,
    required this.senderSide,
    required this.handicap,
    required this.timeControl,
    required this.status,
    required this.expiresAt,
    required this.gameId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => _$ChallengeFromJson(json);

  Map<String, dynamic> toJson() => _$ChallengeToJson(this);
}
