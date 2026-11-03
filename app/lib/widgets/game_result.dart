import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/review_manager.dart';
import '../models/player_state.dart';
import '../theme/app_theme.dart';
import '../utils/rank_format.dart';
import 'board/check_effect.dart';
import 'game_scaffold.dart';
import 'rank_progress_bar.dart';

/// 결과 도장. 이기면 붉은 네모 낙관에 "승", 지면 먹색 둥근 바탕에 "패"를 송명 글꼴로 쓴다(`docs/ui.md`의 연출).
class ResultStamp extends StatelessWidget {
  final bool won;

  /// 도장 한 변.
  final double size;

  const ResultStamp({super.key, required this.won, required this.size});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: won ? CheckColors.stamp : CheckColors.ink,
        shape: won ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: won ? BorderRadius.circular(size * 0.1) : null,
        boxShadow: [
          BoxShadow(
            color: won ? GameColors.goldGlow : CheckColors.inkGlow,
            blurRadius: size * 0.5,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: won ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: won ? BorderRadius.circular(size * 0.06) : null,
          border: Border.all(color: won ? CheckColors.innerLine : GameColors.outline, width: math.max(1, size * 0.025)),
        ),
        child: Center(
          child: Text(
            // 승 / 패
            won ? l10n.resultStampWin : l10n.resultStampLoss,
            maxLines: 1,
            // 도장 크기가 판 크기로 정해지므로 글자 크기 설정을 따르지 않는다.
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: stampFontFamily,
              fontSize: size * (won ? 0.58 : 0.52),
              height: 1.1,
              color: won ? CheckColors.paper : GameColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// 대국이 끝나는 순간 판 가운데에 찍는 결과 도장(`docs/screens.md`의 대국 결과). 판을 어둡게 깔고 도장을 찍고, 아래에
/// "외통승 · 87수" 칩을 둔다. 잠시 머문 뒤 작아지며 [targetKey]의 머리줄 결과 칩 쪽으로 올라가 사라지고 [onLanded]를 부른다.
///
/// 판 영역 크기의 [Stack] 안에 넣는다. 판 밖으로 올라가므로 그 [Stack]은 자르지 않아야 한다.
class ResultStampOverlay extends StatefulWidget {
  static const _duration = Duration(milliseconds: 2400);

  final bool won;

  /// 도장 아래 칩의 글자("외통승 · 87수 · 12분 40초").
  final String detail;

  /// 도장이 올라가 닿을 머리줄 결과 칩.
  final GlobalKey targetKey;
  final VoidCallback onLanded;

  const ResultStampOverlay({
    super.key,
    required this.won,
    required this.detail,
    required this.targetKey,
    required this.onLanded,
  });

  @override
  State<ResultStampOverlay> createState() => _ResultStampOverlayState();
}

class _ResultStampOverlayState extends State<ResultStampOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // 도장 가운데에서 머리줄 결과 칩 가운데까지. 올라가기 시작할 때 잰다.
  Offset? _travel;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ResultStampOverlay._duration)
      ..addListener(_onTick)
      ..addStatusListener(_onStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(animation: _controller, builder: _buildStamp),
    );
  }

  Widget _buildStamp(BuildContext context, Widget? child) {
    final t = _controller.value;
    if (_controller.isCompleted) {
      return const SizedBox.shrink();
    }
    final drop = Curves.easeIn.transform(_interval(t, 0, 300));
    final fly = Curves.easeInOutCubic.transform(_interval(t, 1800, 2400));
    final scrim = _interval(t, 0, 250) * (1 - fly);
    final travel = _travel ?? Offset.zero;
    // 판 크기를 따로 받지 않고 화면 짧은 변에 맞춘다. 판은 화면 폭을 거의 채운다.
    final size = math.min(MediaQuery.sizeOf(context).shortestSide * 0.32, 200.0);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ColoredBox(color: GameColors.scrim.withValues(alpha: GameColors.scrim.a * scrim)),
        ),
        Transform.translate(
          offset: travel * fly,
          child: Transform.scale(
            scale: (1.8 - 0.8 * drop) * (1 - 0.75 * fly),
            child: Opacity(
              opacity: drop * (1 - fly),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: widget.won ? -0.08 : 0,
                    child: ResultStamp(won: widget.won, size: size),
                  ),
                  SizedBox(height: size * 0.22),
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: fly * 4, sigmaY: fly * 4),
                    child: ResultChip(text: widget.detail, won: widget.won),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onFirstFrame(Duration timeStamp) {
    if (!mounted) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      widget.onLanded();
      return;
    }
    _controller.forward();
  }

  /// 올라가기 시작하는 때에 도장과 머리줄 결과 칩의 자리를 잰다. 칩이 아직 그려지지 않았으면 위쪽 끝으로 올라간다.
  void _onTick() {
    if (_travel != null || _controller.value < _intervalStart(1800)) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final target = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (target != null && target.hasSize) {
      _travel = target.localToGlobal(target.size.center(Offset.zero)) - center;
    } else {
      _travel = Offset(0, -box.size.height / 2);
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      widget.onLanded();
    }
  }

  static double _intervalStart(int ms) => ms / ResultStampOverlay._duration.inMilliseconds;

  static double _interval(double t, int startMs, int endMs) {
    final ms = t * ResultStampOverlay._duration.inMilliseconds;
    return ((ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);
  }
}

/// 결과 칩. 이기면 금빛, 지면 차분한 회색이다.
class ResultChip extends StatelessWidget {
  final String text;
  final bool won;

  const ResultChip({super.key, required this.text, required this.won});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: won ? GameColors.goldSurface : GameColors.raisedButton,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppTextSizes.body,
          fontWeight: FontWeight.w800,
          color: won ? GameColors.gold : GameColors.subText,
        ),
      ),
    );
  }
}

/// 대국이 끝난 화면 내 정보 줄의 시계 자리. 이번 급수 대국의 급수 변동을 보여준다(`docs/screens.md`의 대국 결과).
///
/// 이기면 "+1칸"과 다음 급수까지의 어림 승수(초록), 지면 "−1칸"과 "5급 유지"(회색), 급수가 바뀌면 "4급으로 올랐어요"·
/// "6급으로 내려갔어요"다. 대국 서버가 반영하기 전이나 급수 대국이 아니면 보이지 않는다.
class ResultRankChange extends StatelessWidget {
  static const _barWidth = 96.0;

  final String gameId;

  const ResultRankChange({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([managers.playerStateManager, managers.rankManager]),
      builder: _buildChange,
    );
  }

  Widget _buildChange(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final change = managers.playerStateManager.playerState?.lastRankChange;
    if (change == null || change.gameId != gameId) {
      return const SizedBox.shrink();
    }
    final after = change.rankLevelAfter;
    final rankLabel = getRankLabel(l10n, after);
    final up = after > change.rankLevelBefore;
    final down = after < change.rankLevelBefore;
    final gained = _isGained(change, up: up, down: down);
    final String title;
    String? note;
    if (up) {
      // 4급으로 올랐어요
      title = l10n.resultRankUp(rankLabel);
    } else if (down) {
      // 6급으로 내려갔어요
      title = l10n.resultRankDown(rankLabel);
    } else if (gained) {
      // +1칸
      title = l10n.resultRankGain;
    } else {
      // −1칸
      title = l10n.resultRankLoss;
      // 5급 유지
      note = l10n.resultRankKept(rankLabel);
    }
    final wins = managers.rankManager.winsToNextRank;
    if (gained && wins != null && after < maxRankLevel) {
      // 4급까지 약 3승
      note = l10n.rankWinsToNext(getRankLabel(l10n, after + 1), wins);
    }
    final color = gained ? GameColors.accent : GameColors.subText;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: GameColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: _barWidth,
            child: RankProgressBar(
              progress: change.rankProgressAfter,
              previous: _getPrevious(change, up: up, down: down),
              color: GameColors.subText,
              trackColor: GameColors.raisedButton,
              changeColor: gained ? GameColors.accent : GameColors.hanAvatarText,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note,
              style: TextStyle(fontSize: AppTextSizes.body, color: color),
            ),
          ],
        ],
      ),
    );
  }

  /// 진행 막대에서 바뀌기 전 위치. 급수가 바뀌었으면 새 급수 구간의 처음(올랐을 때)이나 끝(내려갔을 때)에서 바뀐 것으로 그린다.
  static double _getPrevious(RankChange change, {required bool up, required bool down}) {
    if (up) {
      return 0;
    }
    if (down) {
      return 1;
    }
    return change.rankProgressBefore;
  }

  static bool _isGained(RankChange change, {required bool up, required bool down}) =>
      change.rankProgressAfter >= _getPrevious(change, up: up, down: down);
}

/// 대국이 끝난 화면의 복기 막대. 처음·이전·"복기 87 / 87수"·다음·끝이다. 가장 많이 쓰는 이전·다음을 강조한다.
class ReviewBar extends StatelessWidget {
  final ReviewManager review;

  const ReviewBar({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: review, builder: _buildBar);
  }

  Widget _buildBar(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final canGoBack = review.ply > 0;
    final canGoForward = review.ply < review.totalMoves;
    return GameButtonBar(
      children: [
        GameBarButton(
          icon: Icons.first_page,
          // 처음
          label: l10n.reviewFirst,
          onPressed: canGoBack ? review.goFirst : null,
        ),
        GameBarButton(
          icon: Icons.chevron_left,
          // 이전
          label: l10n.reviewPrevious,
          onPressed: canGoBack ? review.goPrevious : null,
          emphasized: true,
        ),
        Center(
          child: Text(
            // 복기 4 / 87수
            l10n.reviewBarCounter(review.ply, review.totalMoves),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTextSizes.body,
              fontWeight: FontWeight.w700,
              color: GameColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        GameBarButton(
          icon: Icons.chevron_right,
          // 다음
          label: l10n.reviewNext,
          onPressed: canGoForward ? review.goNext : null,
          emphasized: true,
        ),
        GameBarButton(
          icon: Icons.last_page,
          // 끝
          label: l10n.reviewLast,
          onPressed: canGoForward ? review.goLast : null,
        ),
      ],
    );
  }
}

/// 결과 종류의 이름. [won]이면 이긴 쪽 기준("외통승"), 아니면 진 쪽 기준("외통패")이다.
String getResultReason(AppLocalizations l10n, GameResult result, {required bool won}) {
  // 외통승 / 기권승 / 점수승 / 외통패 / 기권패 / 점수패
  return won ? l10n.resultReason(result.reason.name) : l10n.resultReasonLoss(result.reason.name);
}

/// 결과 도장을 승리 도장으로 찍는지 여부. 대국자는 내 진영 기준이고, 내 진영이 없으면(관전, 한 기기에서 양쪽을 두는 개발용
/// 대국) 이긴 쪽 기준이므로 늘 승리 도장이다(`docs/screens.md`의 대국 결과).
bool isResultWon(GameResult result, Side? mySide) => mySide == null || mySide == result.winner;

/// 머리줄 결과 칩의 글자. 대국자는 "승리 · 외통승"·"패배 · 외통패", 내 진영이 없으면 "초 승리 · 외통승"이다.
String getResultHeadline(AppLocalizations l10n, GameResult result, Side? mySide) {
  final won = isResultWon(result, mySide);
  final String outcome;
  if (mySide == null) {
    // 초 승리 / 한 승리
    outcome = l10n.resultWinner(result.winner.name);
  } else if (won) {
    // 승리
    outcome = l10n.resultOutcomeWin;
  } else {
    // 패배
    outcome = l10n.resultOutcomeLoss;
  }
  // 승리 · 외통승
  return l10n.resultHeadline(outcome, getResultReason(l10n, result, won: won));
}

/// 결과 도장 아래 칩의 글자 "외통승 · 87수 · 12분 40초".
String getResultDetail(AppLocalizations l10n, GameResult result, Side? mySide, int moveCount, Duration elapsed) {
  final reason = getResultReason(l10n, result, won: isResultWon(result, mySide));
  // 외통승 · 87수 · 12분 40초
  return l10n.resultStampDetail(reason, moveCount, elapsed.inMinutes, elapsed.inSeconds % 60);
}
