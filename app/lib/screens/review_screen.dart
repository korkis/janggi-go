import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/review_manager.dart';
import '../theme/app_theme.dart';
import '../utils/score_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/board/board_view.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/player_bar.dart';

/// 복기 화면. 대국 화면과 같은 판을 쓰고 버튼 줄만 바꾼다(`docs/screens.md`의 복기 모드).
///
/// 시계 대신 양쪽 남은 점수를 보여주고, 차례 표시와 기물 어두워짐은 쓰지 않는다. 글자로 된 수 목록은 두지 않는다.
class ReviewScreen extends StatefulWidget {
  final Game record;

  const ReviewScreen({super.key, required this.record});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final ReviewManager _review;

  @override
  void initState() {
    super.initState();
    _review = ReviewManager(record: widget.record);
  }

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      body: ListenableBuilder(listenable: _review, builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    if (getLayoutSize(context) == LayoutSize.expanded) {
      return GameWideLayout(
        onBack: _onBack,
        boardColumn: Column(
          children: [
            _buildPlayerBar(context, Side.han),
            Flexible(child: _buildBoard()),
            _buildPlayerBar(context, Side.cho),
          ],
        ),
        panel: GamePanel(
          // 복기
          title: l10n.reviewTitle,
          body: Column(children: [_buildProgressRow(context)]),
          buttons: _buildButtonBar(context),
        ),
      );
    }
    return Column(
      children: [
        GameHeader(
          // 복기
          title: l10n.reviewTitle,
          onBack: _onBack,
        ),
        _buildPlayerBar(context, Side.han),
        // 판과 아래 정보 줄을 붙여 두고 남는 높이는 버튼 줄 위에 둔다.
        Expanded(
          child: Column(
            children: [
              Flexible(child: _buildBoard()),
              _buildPlayerBar(context, Side.cho),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _buildProgressRow(context)),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: _buildButtonBar(context)),
      ],
    );
  }

  Widget _buildBoard() {
    return BoardView(
      position: _review.position,
      selected: _review.selected,
      targets: _review.targets,
      lastMove: _review.lastMove,
      onSquareTap: _review.trying ? _review.tapSquare : null,
    );
  }

  Widget _buildPlayerBar(BuildContext context, Side side) {
    final l10n = AppLocalizations.of(context);
    return PlayerBar(
      side: side,
      active: false,
      // 72점
      detail: l10n.score(formatScore(_review.position.score(side))),
    );
  }

  /// 몇 수째인지, 끌어서 옮기는 막대, 놓아보기 버튼.
  Widget _buildProgressRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = _review.totalMoves;
    final canSlide = total > 0 && !_review.trying;
    return Row(
      children: [
        Text(
          // 4 / 87수
          l10n.reviewMoveCounter(_review.ply, total),
          style: const TextStyle(
            fontSize: AppTextSizes.body,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Expanded(
          child: Slider(
            value: _review.ply.toDouble(),
            max: total == 0 ? 1 : total.toDouble(),
            divisions: total == 0 ? null : total,
            activeColor: GameColors.accent,
            inactiveColor: GameColors.raisedButton,
            onChanged: canSlide ? _onSlide : null,
          ),
        ),
        _buildTrialButton(context),
      ],
    );
  }

  Widget _buildTrialButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trying = _review.trying;
    return Semantics(
      toggled: trying,
      child: OutlinedButton.icon(
        onPressed: _review.toggleTrial,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(minTouchSize, minTouchSize),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
          backgroundColor: trying ? GameColors.accentSurface : null,
          foregroundColor: trying ? GameColors.accent : GameColors.buttonText,
          side: BorderSide(color: trying ? GameColors.accent : GameColors.outline, width: 1.5),
        ),
        icon: const Icon(Icons.edit_outlined, size: 18),
        // 놓아보기
        label: Text(l10n.reviewTrial),
      ),
    );
  }

  /// 처음, 이전, 다음, 끝. 가장 많이 쓰는 이전·다음을 강조한다. 놓아보기 중에는 끈다.
  Widget _buildButtonBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final movable = !_review.trying;
    final canGoBack = movable && _review.ply > 0;
    final canGoForward = movable && _review.ply < _review.totalMoves;
    return GameButtonBar(
      children: [
        GameBarButton(
          icon: Icons.first_page,
          // 처음
          label: l10n.reviewFirst,
          onPressed: canGoBack ? _review.goFirst : null,
        ),
        GameBarButton(
          icon: Icons.chevron_left,
          // 이전
          label: l10n.reviewPrevious,
          onPressed: canGoBack ? _review.goPrevious : null,
          emphasized: true,
        ),
        GameBarButton(
          icon: Icons.chevron_right,
          // 다음
          label: l10n.reviewNext,
          onPressed: canGoForward ? _review.goNext : null,
          emphasized: true,
        ),
        GameBarButton(
          icon: Icons.last_page,
          // 끝
          label: l10n.reviewLast,
          onPressed: canGoForward ? _review.goLast : null,
        ),
      ],
    );
  }

  void _onSlide(double value) {
    _review.goTo(value.round());
  }

  void _onBack() {
    Navigator.of(context).pop();
  }
}
