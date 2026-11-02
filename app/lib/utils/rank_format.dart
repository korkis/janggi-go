import '../l10n/app_localizations.dart';
import '../models/active_game.dart';

/// 가장 높은 급수(9단)의 rankLevel. 이보다 높은 급수가 없어 다음 급수까지의 진행을 보여주지 않는다(`docs/game/rank.md`).
const maxRankLevel = 27;

// 급(18급~1급)의 가장 높은 rankLevel. 그 위는 단이다(`docs/game/rank.md`).
const _maxKyuRankLevel = 18;

/// rankLevel(1~27)을 "18급", "1단" 같은 글자로 바꾼다.
String getRankLabel(AppLocalizations l10n, int rankLevel) {
  if (rankLevel <= _maxKyuRankLevel) {
    // {kyu}급
    return l10n.rankKyu(_maxKyuRankLevel + 1 - rankLevel);
  }
  // {dan}단
  return l10n.rankDan(rankLevel - _maxKyuRankLevel);
}

/// 대국 정보 줄의 "닉네임 · 18급".
String getPlayerName(AppLocalizations l10n, GamePlayer player) {
  // {nickname} · {rank}
  return l10n.playerNameWithRank(player.nickname, getRankLabel(l10n, player.rankLevel));
}
