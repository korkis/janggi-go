import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:json_annotation/json_annotation.dart';

import 'active_game.dart';
import 'game_enums.dart';
import 'timestamp_converter.dart';

part 'archived_game.g.dart';

/// Firestore `games_archived/{gameId}`. 끝난 대국의 기보와 결과다(`docs/database.md`).
///
/// 대국 서버의 `ArchivedGame`(`server/game/lib/models/archived_game.dart`)과 필드를 일치시킨다. 앱이 쓰지 않는 필드(방, 시간 규칙,
/// 수마다 쓴 시간, 다시 두기)는 읽지 않는다. 닉네임은 저장하지 않으므로 `users/{uid}`에서 지금 닉네임을 읽는다.
@JsonSerializable(createToJson: false)
class ArchivedGame {
  /// 모르는 값이면 null이다(`docs/database.md`: 앱은 모르는 enum 값에 멈추지 않는다).
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final GameMode? mode;

  final bool rated;

  /// `[초 uid, 한 uid]`.
  final List<String> playerUids;
  final ArchivedPlayers players;

  /// 한에서 뗀 기물. 접장기가 아니면 null.
  final List<HandicapPiece>? handicap;

  /// 상차림과 접장기가 반영된 처음 국면.
  final String initialFen;

  /// 수 표기 문자열(`b1c3`, `pass`).
  final List<String> moves;
  final GameResultRecord result;

  @TimestampConverter()
  final DateTime endedAt;

  const ArchivedGame({
    required this.mode,
    required this.rated,
    required this.playerUids,
    required this.players,
    required this.handicap,
    required this.initialFen,
    required this.moves,
    required this.result,
    required this.endedAt,
  });

  factory ArchivedGame.fromJson(Map<String, dynamic> json) => _$ArchivedGameFromJson(json);
}

@JsonSerializable(createToJson: false)
class ArchivedPlayers {
  final ArchivedPlayer cho;
  final ArchivedPlayer han;

  const ArchivedPlayers({required this.cho, required this.han});

  ArchivedPlayer get(Side side) => side == Side.cho ? cho : han;

  factory ArchivedPlayers.fromJson(Map<String, dynamic> json) => _$ArchivedPlayersFromJson(json);
}

@JsonSerializable(createToJson: false)
class ArchivedPlayer {
  final String uid;

  /// 대국 시작 때의 급수.
  final int rankLevel;

  const ArchivedPlayer({required this.uid, required this.rankLevel});

  factory ArchivedPlayer.fromJson(Map<String, dynamic> json) => _$ArchivedPlayerFromJson(json);
}
