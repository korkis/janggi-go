import '../l10n/app_localizations.dart';

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
