import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/score_format.dart';
import '../widgets/player_bar.dart';

/// 대국 결과 창에서 고른 다음 할 일.
enum GameResultAction { rematch, review, home }

/// 대국 결과 창. 끝난 판을 뒤에 둔 채 아래에서 올라온다.
///
/// 급수 변동과 한 판 더는 빠른 대국(7단계)에서 붙인다.
class GameResultSheet extends StatelessWidget {
  final GameResult result;
  final int moveCount;
  final Duration elapsed;

  /// 다시 두기 버튼을 보여준다. 온라인 대국의 다시 두기는 7단계에서 붙이므로 지금은 개발용 대국에서만 true다.
  final bool rematchAvailable;

  const GameResultSheet({
    super.key,
    required this.result,
    required this.moveCount,
    required this.elapsed,
    this.rematchAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = _getScoreDetail(l10n);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: GameColors.accentSurface, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  // 외통승 / 기권승 / 점수승
                  l10n.resultReason(result.reason.name),
                  style: const TextStyle(
                    fontSize: AppTextSizes.body,
                    fontWeight: FontWeight.w800,
                    color: GameColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              // 초 승리 / 한 승리
              l10n.resultWinner(result.winner.name),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: AppTextSizes.headline, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              // 87수 · 12분 40초
              l10n.resultSummary(moveCount, elapsed.inMinutes, elapsed.inSeconds % 60),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _buildScoreCard(context, Side.cho, result.choScore)),
                const SizedBox(width: 10),
                Expanded(child: _buildScoreCard(context, Side.han, result.hanScore)),
              ],
            ),
            const SizedBox(height: 18),
            if (rematchAvailable) ...[
              FilledButton(
                onPressed: () => Navigator.of(context).pop(GameResultAction.rematch),
                // 다시 두기
                child: Text(l10n.resultRematch),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(GameResultAction.review),
                    // 복기하기
                    child: Text(l10n.resultReview),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(GameResultAction.home),
                    // 홈으로
                    child: Text(l10n.resultHome),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 점수 판정으로 끝났을 때 왜 점수로 정했는지 설명한다. 완승이면 null이다.
  String? _getScoreDetail(AppLocalizations l10n) {
    switch (result.reason) {
      case GameEndReason.consecutivePasses:
        // 양쪽이 연속으로 한수쉼을 해서 점수로 정했어요
        return l10n.resultConsecutivePasses;
      case GameEndReason.moveLimit:
        // 200수에 닿아서 점수로 정했어요
        return l10n.resultMoveLimit(Game.maxMoves);
      case GameEndReason.noLegalMoves:
        // 둘 수 있는 수가 없어서 점수로 정했어요
        return l10n.resultNoLegalMoves;
      case GameEndReason.checkmate:
      case GameEndReason.resignation:
      case GameEndReason.timeout:
      case GameEndReason.disconnect:
        return null;
    }
  }

  Widget _buildScoreCard(BuildContext context, Side side, double score) {
    final l10n = AppLocalizations.of(context);
    final won = side == result.winner;
    final color = won ? GameColors.text : GameColors.subText;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GameColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: won ? GameColors.accent : Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          SideAvatar(side: side, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // 초 / 한
                  l10n.sideName(side.name),
                  style: TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700, color: color),
                ),
                Text(
                  // 64점
                  l10n.score(formatScore(score)),
                  style: TextStyle(
                    fontSize: AppTextSizes.body,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
