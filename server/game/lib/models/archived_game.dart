import 'package:janggi_core/janggi_core.dart';
import 'package:json_annotation/json_annotation.dart';

import 'active_game.dart';
import 'game_enums.dart';
import 'timestamp_converter.dart';

part 'archived_game.g.dart';

/// Firestore `games_archived/{gameId}`. 끝난 대국의 기보와 결과다(`docs/database.md`).
///
/// 대국 서버가 `finalizeGame`에서 한 번만 만든다. 닉네임은 저장하지 않는다.
@JsonSerializable(createToJson: true, explicitToJson: true)
class ArchivedGame {
  final GameMode mode;
  final bool rated;
  final String? roomId;

  /// `[초 uid, 한 uid]`. 내 기보 목록 조회용.
  final List<String> playerUids;

  /// 두 uid를 정렬해 `_`로 이은 값. 나와의 전적 조회용.
  final String pairKey;
  final ArchivedPlayers players;

  /// 한에서 뗀 기물. 접장기가 아니면 null.
  final List<HandicapPiece>? handicap;
  final TimeControl timeControl;

  /// 상차림과 접장기가 반영된 처음 국면.
  final String initialFen;

  /// 수 표기 문자열.
  final List<String> moves;

  /// 각 수에 쓴 시간(밀리초).
  final List<int> moveTimesMs;
  final GameResultRecord result;
  final String? rematchOf;

  /// 상차림을 시작한 시각.
  @TimestampConverter()
  final DateTime startedAt;

  @TimestampConverter()
  final DateTime endedAt;

  const ArchivedGame({
    required this.mode,
    required this.rated,
    required this.roomId,
    required this.playerUids,
    required this.pairKey,
    required this.players,
    required this.handicap,
    required this.timeControl,
    required this.initialFen,
    required this.moves,
    required this.moveTimesMs,
    required this.result,
    required this.rematchOf,
    required this.startedAt,
    required this.endedAt,
  });

  factory ArchivedGame.fromJson(Map<String, dynamic> json) => _$ArchivedGameFromJson(json);

  Map<String, dynamic> toJson() => _$ArchivedGameToJson(this);
}

@JsonSerializable(createToJson: true, explicitToJson: true)
class ArchivedPlayers {
  final ArchivedPlayer cho;
  final ArchivedPlayer han;

  const ArchivedPlayers({required this.cho, required this.han});

  factory ArchivedPlayers.fromJson(Map<String, dynamic> json) => _$ArchivedPlayersFromJson(json);

  Map<String, dynamic> toJson() => _$ArchivedPlayersToJson(this);
}

@JsonSerializable(createToJson: true)
class ArchivedPlayer {
  final String uid;

  /// 대국 시작 때의 급수.
  final int rankLevel;

  const ArchivedPlayer({required this.uid, required this.rankLevel});

  factory ArchivedPlayer.fromJson(Map<String, dynamic> json) => _$ArchivedPlayerFromJson(json);

  Map<String, dynamic> toJson() => _$ArchivedPlayerToJson(this);
}
