import 'package:janggi_core/janggi_core.dart';
import 'package:json_annotation/json_annotation.dart';

import 'game_enums.dart';
import 'timestamp_converter.dart';

part 'room.g.dart';

/// Firestore `rooms/{roomId}`. 방이다(`docs/database.md`). 대국이 끝나도 방장이 나가기 전까지 유지한다.
///
/// 대국 서버만 쓴다. 필드는 앱의 `Room`(`app/lib/models/room.dart`)과 일치시킨다.
@JsonSerializable(createToJson: true, explicitToJson: true)
class Room {
  final String hostUid;

  /// 방 목록 표시용 방장 정보.
  final RoomPlayer host;
  final String? guestUid;
  final RoomPlayer? guest;
  final RoomStatus status;

  /// 방 목록에 공개한다.
  final bool listed;

  /// 방장의 진영. 접장기면 떼는 쪽이 한이므로 쓰지 않는다.
  final SideChoice hostSide;
  final RoomHandicap? handicap;

  /// 들어올 수 있는 급수(`rankLevel`). 공개 방에서만 쓴다. null이면 모든 급수.
  final RankRange? rankRange;

  /// 진행 중이거나 마지막으로 둔 대국.
  final String? gameId;

  /// 방장이 내보낸 사람. 방이 닫힐 때까지 다시 들어올 수 없다.
  final List<String> kickedUids;

  /// `checkRoom` 예약 작업이 방장의 연결이 없는 것을 처음 본 시각. 연결이 있으면 null.
  @TimestampConverter()
  final DateTime? hostAbsentSince;

  /// `checkRoom` 예약 작업이 상대의 연결이 없는 것을 처음 본 시각. 연결이 있거나 상대가 없으면 null.
  @TimestampConverter()
  final DateTime? guestAbsentSince;

  @TimestampConverter()
  final DateTime createdAt;

  @TimestampConverter()
  final DateTime updatedAt;

  const Room({
    required this.hostUid,
    required this.host,
    required this.guestUid,
    required this.guest,
    required this.status,
    required this.listed,
    required this.hostSide,
    required this.handicap,
    required this.rankRange,
    required this.gameId,
    required this.kickedUids,
    required this.hostAbsentSince,
    required this.guestAbsentSince,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);

  Map<String, dynamic> toJson() => _$RoomToJson(this);
}

/// 방의 방장 또는 상대. 들어올 때의 닉네임과 급수다.
@JsonSerializable(createToJson: true)
class RoomPlayer {
  final String nickname;
  final int rankLevel;

  const RoomPlayer({required this.nickname, required this.rankLevel});

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => _$RoomPlayerFromJson(json);

  Map<String, dynamic> toJson() => _$RoomPlayerToJson(this);
}

/// 방의 접장기 조건. 떼는 쪽이 한을 잡는다.
@JsonSerializable(createToJson: true)
class RoomHandicap {
  final HandicapRemover remover;

  /// 한에서 뗄 기물. 하나 이상이다.
  final List<HandicapPiece> pieces;

  const RoomHandicap({required this.remover, required this.pieces});

  factory RoomHandicap.fromJson(Map<String, dynamic> json) => _$RoomHandicapFromJson(json);

  Map<String, dynamic> toJson() => _$RoomHandicapToJson(this);
}

/// 들어올 수 있는 급수 범위. 양 끝을 포함한다.
@JsonSerializable(createToJson: true)
class RankRange {
  final int min;
  final int max;

  const RankRange({required this.min, required this.max});

  factory RankRange.fromJson(Map<String, dynamic> json) => _$RankRangeFromJson(json);

  Map<String, dynamic> toJson() => _$RankRangeToJson(this);
}
