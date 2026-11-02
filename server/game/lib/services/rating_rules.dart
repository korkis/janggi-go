import 'dart:math';

import '../config.dart';

// 레이팅과 급수 계산(`docs/game/rank.md`). DB에 닿지 않는 순수 함수다. 값은 `config.dart`의 서버 설정을 쓴다.

/// 급수 대국 하나를 반영한 뒤의 값.
class RatedOutcome {
  final double rating;

  /// 이 대국을 더한 반영 대국 수.
  final int ratedGames;
  final int rankLevel;

  /// 바뀐 급수 구간 안에서의 위치 0~1.
  final double rankProgress;

  /// 다음 급수까지의 어림 승수. 9단이면 null.
  final int? winsToNextRank;

  const RatedOutcome({
    required this.rating,
    required this.ratedGames,
    required this.rankLevel,
    required this.rankProgress,
    required this.winsToNextRank,
  });
}

/// 반영된 대국 수가 [ratedGames]인 사용자의 K 값.
int getRatingK(int ratedGames) {
  for (final step in ratingKSteps) {
    final upTo = step.ratedGamesUpTo;
    if (upTo == null || ratedGames <= upTo) {
      return step.k;
    }
  }
  throw StateError('ratingKSteps의 마지막 단계는 ratedGamesUpTo가 null이어야 합니다');
}

/// [rating]인 사람이 [opponentRating]인 상대를 이길 기대 승률.
double getExpectedScore(double rating, double opponentRating) => 1 / (1 + pow(10, (opponentRating - rating) / 400));

/// [rating]이 들어가는 급수(1이 18급, [maxRankLevel]이 9단). 급수 구간으로 바로 정하고 강등 보호는 없다.
int getRankLevel(double rating) {
  final level = 1 + ((rating - rankBaseRating) / rankBandWidth).floor();
  return level.clamp(1, maxRankLevel);
}

/// [rating]이 지금 급수 구간 안에서 어디쯤인지 0~1. 진행 막대에 쓴다. 9단은 다음 급수가 없으므로 1이다.
double getRankProgress(double rating) {
  final level = getRankLevel(rating);
  if (level == maxRankLevel) {
    return 1;
  }
  final bandStart = rankBaseRating + (level - 1) * rankBandWidth;
  return ((rating - bandStart) / rankBandWidth).clamp(0.0, 1.0);
}

/// 다음 급수까지의 어림 승수. 비슷한 레이팅의 상대를 이기면 다음 판의 K의 절반쯤 오른다는 어림이다. 9단이면 null.
int? getWinsToNextRank(double rating, int ratedGames) {
  final level = getRankLevel(rating);
  if (level == maxRankLevel) {
    return null;
  }
  final nextStart = rankBaseRating + level * rankBandWidth;
  final wins = ((nextStart - rating) / (getRatingK(ratedGames) * 0.5)).ceil();
  return max(1, wins);
}

/// [rating]인 사람이 반영된 대국 [ratedGames]판 뒤에 [opponentRating]인 상대에게 이기거나([won]) 진 결과.
RatedOutcome getRatedOutcome({
  required double rating,
  required int ratedGames,
  required double opponentRating,
  required bool won,
}) {
  final score = won ? 1.0 : 0.0;
  final nextRating = rating + getRatingK(ratedGames) * (score - getExpectedScore(rating, opponentRating));
  final nextRatedGames = ratedGames + 1;
  return RatedOutcome(
    rating: nextRating,
    ratedGames: nextRatedGames,
    rankLevel: getRankLevel(nextRating),
    rankProgress: getRankProgress(nextRating),
    winsToNextRank: getWinsToNextRank(nextRating, nextRatedGames),
  );
}

/// 빠른 대국 대기열에서 [waited]만큼 기다린 사람에게 허용하는 레이팅 차이(`docs/game/rank.md`의 빠른 대국 매칭).
/// [stepInterval]마다 [quickMatchRangeStep]씩 넓히고 [quickMatchMaxRange]에서 멈춘다.
double getQuickMatchRange(Duration waited, {Duration stepInterval = quickMatchStepInterval}) {
  final steps = waited.isNegative ? 0 : waited.inMilliseconds ~/ stepInterval.inMilliseconds;
  return min(quickMatchInitialRange + steps * quickMatchRangeStep, quickMatchMaxRange);
}
