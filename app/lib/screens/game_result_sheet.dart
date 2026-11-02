import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/online_game_manager.dart';
import '../models/game_enums.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/rank_format.dart';
import '../utils/score_format.dart';
import '../widgets/player_bar.dart';
import '../widgets/rank_progress_bar.dart';

/// 대국 결과 창에서 고른 다음 할 일.
enum GameResultAction {
  /// 한 판 더. 새 빠른 대국을 찾는다.
  playAgain,

  /// 다시 두기. 온라인 대국이면 새 대국에 이미 묶인 뒤다.
  rematch,
  review,

  /// 홈으로. 방 대국이면 방 대기실로 돌아간다.
  home,
}

/// 대국 결과 창. 끝난 판을 뒤에 둔 채 아래에서 올라온다(`docs/screens.md`의 대국 결과).
///
/// 온라인 대국([online]이 있다)은 급수 대국이면 급수 변동을 보여주고, 다시 두기는 대국 서버에 보내 두 사람이 모두 누르면
/// 새 대국에 묶인 뒤 창을 닫는다. 빠른 대국이면 가장 큰 버튼으로 한 판 더를 둔다.
class GameResultSheet extends StatefulWidget {
  final GameResult result;
  final int moveCount;
  final Duration elapsed;

  /// 온라인 대국. 개발용 대국이면 null이고 다시 두기는 같은 기기에서 바로 다시 둔다.
  final OnlineGameManager? online;

  const GameResultSheet({super.key, required this.result, required this.moveCount, required this.elapsed, this.online});

  @override
  State<GameResultSheet> createState() => _GameResultSheetState();
}

class _GameResultSheetState extends State<GameResultSheet> {
  // 다시 두기를 보내는 중이다.
  var _rematchSending = false;

  // 다시 두기로 창을 닫았다.
  var _closed = false;

  GameResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    widget.online?.addListener(_onRematchChanged);
    managers.playerStateManager.addListener(_onRematchChanged);
  }

  @override
  void dispose() {
    widget.online?.removeListener(_onRematchChanged);
    managers.playerStateManager.removeListener(_onRematchChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = _getScoreDetail(l10n);
    final online = widget.online;
    final quick = online?.game?.meta.mode == GameMode.quick;
    final inRoom = online?.game?.meta.roomId != null;
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
              l10n.resultSummary(widget.moveCount, widget.elapsed.inMinutes, widget.elapsed.inSeconds % 60),
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
            if (online != null)
              ListenableBuilder(
                listenable: Listenable.merge([managers.playerStateManager, managers.rankManager]),
                builder: _buildRankChange,
              ),
            const SizedBox(height: 18),
            if (quick) ...[
              FilledButton(
                onPressed: () => Navigator.of(context).pop(GameResultAction.playAgain),
                // 한 판 더
                child: Text(l10n.resultPlayAgain),
              ),
              const SizedBox(height: 10),
            ],
            if (online != null)
              ListenableBuilder(listenable: online, builder: _buildOnlineRematch)
            else
              FilledButton(
                onPressed: () => Navigator.of(context).pop(GameResultAction.rematch),
                // 다시 두기
                child: Text(l10n.resultRematch),
              ),
            const SizedBox(height: 10),
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
                    // 방 대기실로 / 홈으로
                    child: Text(inRoom ? l10n.resultBackToRoom : l10n.resultHome),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 이번 급수 대국의 급수 변동. 대국 서버가 반영하기 전이나 급수 대국이 아니면 보이지 않는다.
  Widget _buildRankChange(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final change = managers.playerStateManager.playerState?.lastRankChange;
    if (change == null || change.gameId != widget.online?.gameId) {
      return const SizedBox.shrink();
    }
    final after = change.rankLevelAfter;
    final rankLabel = getRankLabel(l10n, after);
    final up = after > change.rankLevelBefore;
    final down = after < change.rankLevelBefore;
    final String title;
    if (up) {
      // 4급으로 올랐어요
      title = l10n.resultRankUp(rankLabel);
    } else if (down) {
      // 6급으로 내려갔어요
      title = l10n.resultRankDown(rankLabel);
    } else {
      title = rankLabel;
    }
    // 급수가 바뀌었으면 새 급수 구간의 처음(올랐을 때)이나 끝(내려갔을 때)에서 바뀐 것으로 그린다.
    final double previous;
    if (up) {
      previous = 0;
    } else if (down) {
      previous = 1;
    } else {
      previous = change.rankProgressBefore;
    }
    final gained = change.rankProgressAfter >= previous;
    final wins = managers.rankManager.winsToNextRank;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GameColors.background, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: AppTextSizes.body,
                fontWeight: FontWeight.w800,
                color: up ? GameColors.accent : GameColors.text,
              ),
            ),
            const SizedBox(height: 10),
            RankProgressBar(
              progress: change.rankProgressAfter,
              previous: previous,
              color: GameColors.subText,
              trackColor: GameColors.raisedButton,
              changeColor: gained ? GameColors.accent : GameColors.hanAvatarText,
            ),
            if (wins != null && after < maxRankLevel) ...[
              const SizedBox(height: 8),
              Text(
                // 4급까지 약 3승
                l10n.rankWinsToNext(getRankLabel(l10n, after + 1), wins),
                style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 온라인 대국의 다시 두기 버튼과 상태. 내가 눌렀으면 상대를 기다리고, 상대가 나갔거나 횟수에 닿았으면 끈다.
  Widget _buildOnlineRematch(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final online = widget.online!;
    final rematch = online.game?.rematch;
    final mySide = online.mySide;
    final pressed = mySide != null && rematch?.get(mySide) == true;
    final opponentPressed = mySide != null && rematch?.get(mySide.opponent) == true;
    final blocked = rematch?.blocked == true;
    final cancelled = rematch?.cancelled == true && rematch?.gameId == null;
    final String? note;
    if (blocked) {
      // 같은 상대와는 더 다시 둘 수 없어요
      note = l10n.resultRematchBlocked;
    } else if (cancelled) {
      // 상대가 나가서 다시 둘 수 없어요
      note = l10n.resultRematchCancelled;
    } else if (opponentPressed && !pressed) {
      // 상대가 다시 두기를 원해요
      note = l10n.resultRematchRequested;
    } else {
      note = null;
    }
    final enabled = !blocked && !cancelled && !pressed && !_rematchSending && rematch?.gameId == null;
    // 상대를 기다리는 중 / 다시 두기
    final label = Text(pressed ? l10n.resultRematchWaiting : l10n.resultRematch);
    final quick = online.game?.meta.mode == GameMode.quick;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quick)
          OutlinedButton(onPressed: enabled ? _onRematch : null, child: label)
        else
          FilledButton(onPressed: enabled ? _onRematch : null, child: label),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(
            note,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTextSizes.body,
              color: opponentPressed && !pressed && !blocked && !cancelled ? GameColors.accent : GameColors.subText,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onRematch() async {
    final online = widget.online!;
    try {
      setState(() {
        _rematchSending = true;
      });
      await repositories.gameRepository.requestRematch(online.gameId);
    } catch (error, stackTrace) {
      developer.log('GameRepository.requestRematch 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 다시 두기를 하지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorRematch;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _rematchSending = false;
        });
      }
    }
  }

  /// 다시 두기 대국이 정해지고 내가 그 대국에 묶이면 창을 닫는다. 대국 화면이 새 대국의 상차림으로 옮겨 간다.
  void _onRematchChanged() {
    final rematchGameId = widget.online?.game?.rematch?.gameId;
    if (_closed || rematchGameId == null || managers.playerStateManager.gameId != rematchGameId) {
      return;
    }
    _closed = true;
    Navigator.of(context).pop(GameResultAction.rematch);
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
