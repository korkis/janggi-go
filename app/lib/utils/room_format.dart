import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../models/room.dart';
import 'rank_format.dart';

// 방 조건을 글자로 바꾼다. 방 만들기, 방 대기실, 방 목록이 같이 쓴다.

/// 방 이름. "장기왕의 방".
String getRoomTitle(AppLocalizations l10n, Room room) {
  // {nickname}의 방
  return l10n.roomTitle(room.host.nickname);
}

/// 들어올 수 있는 급수. null이면 "모든 급수", 아니면 "18급 ~ 1단".
String getRankRangeLabel(AppLocalizations l10n, RankRange? rankRange) {
  if (rankRange == null) {
    // 모든 급수
    return l10n.rankRangeAll;
  }
  // {min} ~ {max}
  return l10n.rankRange(getRankLabel(l10n, rankRange.min), getRankLabel(l10n, rankRange.max));
}

/// 접장기 요약. "차, 포 떼기 · 20점 적게 시작". 뗀 기물의 점수 합만큼 적게 시작한다(`docs/game/handicap.md`).
String getHandicapSummary(AppLocalizations l10n, List<HandicapPiece> pieces) {
  // 차 / 포 / 마 / 상
  final names = [for (final piece in pieces) l10n.pieceName(piece.type.name)];
  var points = 0;
  for (final piece in pieces) {
    points += piece.type.score;
  }
  // {pieces} 떼기 · {points}점 적게 시작
  return l10n.handicapSummary(names.join(', '), points);
}
