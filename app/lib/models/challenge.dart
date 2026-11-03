import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import 'active_game.dart';
import 'game_enums.dart';
import 'room.dart';
import 'timestamp_converter.dart';

part 'challenge.g.dart';

/// Firestore `challenges/{challengeId}`. 대국 신청이다(`docs/database.md`).
///
/// 대국 서버만 쓰고 앱은 보낸 사람과 받는 사람만 읽는다. 필드는 대국 서버의 `Challenge`
/// (`server/game/lib/models/challenge.dart`)와 일치시킨다.
@JsonSerializable(createToJson: false)
class Challenge {
  final String fromUid;

  /// 신청한 사람의 닉네임과 급수. 모양이 방의 방장 정보와 같다.
  final RoomPlayer from;
  final String toUid;

  /// 방 대기실의 접속자 초대면 그 방. 수락하면 방에 들어간다.
  final String? roomId;

  /// 신청한 사람의 진영. 접장기면 떼는 쪽이 한이므로 null이다.
  final SideChoice? senderSide;

  /// 접장기 조건. `remover`는 신청한 사람 기준이다.
  final RoomHandicap? handicap;

  /// 수락하면 둘 대국의 시간 규칙.
  final TimeControl timeControl;

  /// 모르는 값이면 null이다. 화면은 끝난 신청으로 본다.
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final ChallengeStatus? status;

  /// 수락해서 만든 대국.
  final String? gameId;

  /// 응답 마감. 남은 시간 막대에 쓴다.
  @TimestampConverter()
  final DateTime expiresAt;

  @TimestampConverter()
  final DateTime createdAt;

  const Challenge({
    required this.fromUid,
    required this.from,
    required this.toUid,
    required this.roomId,
    required this.senderSide,
    required this.handicap,
    required this.timeControl,
    required this.status,
    required this.gameId,
    required this.expiresAt,
    required this.createdAt,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => _$ChallengeFromJson(json);
}
