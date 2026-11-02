import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'player_state.g.dart';

/// Firestore `player_states/{uid}`. 사용자가 지금 무엇을 하고 있는지다(`docs/database.md`).
///
/// 대국 서버만 쓰고 앱은 본인 문서를 듣기만 한다. 필드는 대국 서버의 `PlayerState`(`server/game/lib/models/player_state.dart`)와
/// 일치시킨다.
@JsonSerializable(createToJson: false)
class PlayerState {
  final String? roomId;

  /// 진행 중(상차림 포함) 대국. 끝나면 null.
  final String? gameId;

  /// 마지막으로 끝난 대국.
  final String? lastGameId;
  final String? outgoingChallengeId;
  final String? incomingChallengeId;

  /// 상차림 화면에서 골라 둔 것.
  final SetupDraft? setupDraft;

  /// 마지막 급수 대국의 변동. 7단계(빠른 대국)부터 쓴다.
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
}

@JsonSerializable(createToJson: false)
class SetupDraft {
  final String gameId;
  final Formation formation;

  const SetupDraft({required this.gameId, required this.formation});

  factory SetupDraft.fromJson(Map<String, dynamic> json) => _$SetupDraftFromJson(json);
}

@JsonSerializable(createToJson: false)
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
}
