import 'package:janggi_core/janggi_core.dart';
import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'player_state.g.dart';

/// Firestore `player_states/{uid}`. 사용자가 지금 무엇을 하고 있는지다(`docs/database.md`).
///
/// 대국 서버만 쓰고 본인 앱은 듣기만 한다. 필드는 앱의 `PlayerState`(`app/lib/models/player_state.dart`)와 일치시킨다.
/// 한 사람이 대기열, 방, 대국, 신청 중 한 가지에만 있도록 대국 서버가 트랜잭션으로 관리한다.
@JsonSerializable(createToJson: true, explicitToJson: true)
class PlayerState {
  final String? roomId;

  /// 진행 중(상차림 포함) 대국. 끝나면 null.
  final String? gameId;

  /// 마지막으로 끝난 대국.
  final String? lastGameId;
  final String? outgoingChallengeId;
  final String? incomingChallengeId;

  /// 상차림 화면에서 골라 둔 것. 상대에게 보이면 안 되므로 RTDB가 아니라 여기 둔다.
  final SetupDraft? setupDraft;

  /// 마지막 급수 대국의 변동. 결과 창의 급수 변동에 쓴다.
  final RankChange? lastRankChange;

  @TimestampConverter()
  final DateTime? quickQueueJoinedAt;

  @TimestampConverter()
  final DateTime updatedAt;

  const PlayerState({
    required this.roomId,
    required this.gameId,
    required this.lastGameId,
    required this.outgoingChallengeId,
    required this.incomingChallengeId,
    required this.setupDraft,
    required this.lastRankChange,
    required this.quickQueueJoinedAt,
    required this.updatedAt,
  });

  factory PlayerState.fromJson(Map<String, dynamic> json) => _$PlayerStateFromJson(json);

  Map<String, dynamic> toJson() => _$PlayerStateToJson(this);
}

@JsonSerializable(createToJson: true)
class SetupDraft {
  final String gameId;
  final Formation formation;

  const SetupDraft({required this.gameId, required this.formation});

  factory SetupDraft.fromJson(Map<String, dynamic> json) => _$SetupDraftFromJson(json);

  Map<String, dynamic> toJson() => _$SetupDraftToJson(this);
}

@JsonSerializable(createToJson: true)
class RankChange {
  final String gameId;
  final int rankLevelBefore;
  final int rankLevelAfter;

  /// 급수 구간 안에서의 위치 0~1.
  final double rankProgressBefore;
  final double rankProgressAfter;

  const RankChange({
    required this.gameId,
    required this.rankLevelBefore,
    required this.rankLevelAfter,
    required this.rankProgressBefore,
    required this.rankProgressAfter,
  });

  factory RankChange.fromJson(Map<String, dynamic> json) => _$RankChangeFromJson(json);

  Map<String, dynamic> toJson() => _$RankChangeToJson(this);
}
