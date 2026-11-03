import 'package:json_annotation/json_annotation.dart';

part 'spectate_list_entry.g.dart';

/// RTDB `spectate_list/{gameId}`. 관전 목록 카드 하나다(`docs/database.md`).
///
/// 대국 서버만 쓴다. 필드는 대국 서버의 `SpectateListEntry`(`server/game/lib/models/spectate_list_entry.dart`)와
/// 일치시킨다.
@JsonSerializable(createToJson: false)
class SpectateListEntry {
  final SpectatePlayers players;

  /// 지금 국면. 판 미리보기에 쓴다.
  final String fen;

  final int moveCount;

  /// 접장기 대국이다.
  final bool handicapped;

  /// 대국 서버가 수를 받을 때 센 관전자 수. 로그인하지 않은 관전자도 센다.
  final int spectatorCount;

  /// 상차림을 시작한 시각(ms).
  final int startedAt;

  const SpectateListEntry({
    required this.players,
    required this.fen,
    required this.moveCount,
    required this.handicapped,
    required this.spectatorCount,
    required this.startedAt,
  });

  factory SpectateListEntry.fromJson(Map<String, dynamic> json) => _$SpectateListEntryFromJson(json);
}

@JsonSerializable(createToJson: false)
class SpectatePlayers {
  final SpectatePlayer cho;
  final SpectatePlayer han;

  const SpectatePlayers({required this.cho, required this.han});

  factory SpectatePlayers.fromJson(Map<String, dynamic> json) => _$SpectatePlayersFromJson(json);
}

@JsonSerializable(createToJson: false)
class SpectatePlayer {
  final String nickname;
  final int rankLevel;

  const SpectatePlayer({required this.nickname, required this.rankLevel});

  factory SpectatePlayer.fromJson(Map<String, dynamic> json) => _$SpectatePlayerFromJson(json);
}
