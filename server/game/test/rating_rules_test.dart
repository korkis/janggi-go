import 'package:janggigo_game/config.dart';
import 'package:janggigo_game/services/rating_rules.dart';
import 'package:test/test.dart';

void main() {
  group('K 값', () {
    test('반영된 대국 수에 따라 80, 40, 20이다', () {
      expect(getRatingK(0), 80);
      expect(getRatingK(19), 80);
      expect(getRatingK(20), 40);
      expect(getRatingK(99), 40);
      expect(getRatingK(100), 20);
      expect(getRatingK(5000), 20);
    });
  });

  group('급수', () {
    test('18급은 1050 미만, 50점마다 한 단계, 9단은 2300 이상이다', () {
      expect(getRankLevel(initialRating), 1);
      expect(getRankLevel(800), 1);
      expect(getRankLevel(1049.9), 1);
      expect(getRankLevel(1050), 2);
      expect(getRankLevel(1850), 18);
      expect(getRankLevel(1899.9), 18);
      expect(getRankLevel(1900), 19);
      expect(getRankLevel(2299.9), 26);
      expect(getRankLevel(2300), maxRankLevel);
      expect(getRankLevel(3000), maxRankLevel);
    });

    test('진행 막대는 급수 구간 안의 위치이고 18급 아래는 0, 9단은 1이다', () {
      expect(getRankProgress(1000), 0);
      expect(getRankProgress(900), 0);
      expect(getRankProgress(1025), closeTo(0.5, 1e-9));
      expect(getRankProgress(1060), closeTo(0.2, 1e-9));
      expect(getRankProgress(2400), 1);
    });

    test('어림 승수는 다음 급수까지 K의 절반씩 오른다고 보고 올림한다', () {
      // 1000 → 1050: 50 ÷ 40 = 1.25 → 2승.
      expect(getWinsToNextRank(1000, 0), 2);
      // 20판부터 K 40: 50 ÷ 20 = 2.5 → 3승.
      expect(getWinsToNextRank(1000, 20), 3);
      // 다음 급수 바로 아래여도 1승.
      expect(getWinsToNextRank(1049.99, 0), 1);
      expect(getWinsToNextRank(2300, 100), isNull);
    });
  });

  group('대국 결과', () {
    test('같은 레이팅끼리면 이긴 쪽이 K의 절반 오르고 진 쪽이 내려간다', () {
      final won = getRatedOutcome(rating: 1000, ratedGames: 0, opponentRating: 1000, won: true);
      expect(won.rating, closeTo(1040, 1e-9));
      expect(won.ratedGames, 1);
      expect(won.rankLevel, 1);
      expect(won.rankProgress, closeTo(0.8, 1e-9));
      expect(won.winsToNextRank, 1);

      final lost = getRatedOutcome(rating: 1000, ratedGames: 0, opponentRating: 1000, won: false);
      expect(lost.rating, closeTo(960, 1e-9));
      expect(lost.rankLevel, 1);
      expect(lost.rankProgress, 0);
    });

    test('높은 상대를 이기면 더 많이 오르고 구간을 넘으면 급수가 바로 오른다', () {
      final upset = getRatedOutcome(rating: 1040, ratedGames: 30, opponentRating: 1440, won: true);
      // 기대 승률 1/11, K 40.
      expect(upset.rating, closeTo(1040 + 40 * (1 - 1 / 11), 1e-9));
      expect(upset.rankLevel, 2);
    });

    test('구간 아래로 내려가면 급수가 바로 내려간다', () {
      final dropped = getRatedOutcome(rating: 1105, ratedGames: 150, opponentRating: 1105, won: false);
      expect(dropped.rating, closeTo(1095, 1e-9));
      expect(dropped.rankLevel, 2);
    });
  });

  group('빠른 대국 매칭 범위', () {
    test('처음 100점에서 10초마다 50점씩 넓혀 400점에서 멈춘다', () {
      expect(getQuickMatchRange(Duration.zero), 100);
      expect(getQuickMatchRange(const Duration(seconds: 9)), 100);
      expect(getQuickMatchRange(const Duration(seconds: 10)), 150);
      expect(getQuickMatchRange(const Duration(seconds: 59)), 350);
      expect(getQuickMatchRange(const Duration(seconds: 60)), 400);
      expect(getQuickMatchRange(const Duration(minutes: 10)), 400);
      expect(getQuickMatchRange(const Duration(seconds: -1)), 100);
    });

    test('간격을 바꿀 수 있다', () {
      expect(getQuickMatchRange(const Duration(seconds: 2), stepInterval: const Duration(seconds: 1)), 200);
    });
  });
}
