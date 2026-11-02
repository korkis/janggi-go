import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/board_manager.dart';
import '../theme/app_theme.dart';
import '../utils/dialog_utils.dart';
import '../utils/score_format.dart';
import '../widgets/board/board_view.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/player_bar.dart';
import 'game_result_sheet.dart';
import 'setup_screen.dart';

/// 대국 화면. 지금은 서버 없이 한 기기에서 양쪽을 두는 개발용 대국이다.
///
/// 초가 아래에 오고, 차례가 아닌 쪽의 기물을 살짝 어둡게 한다.
class GameScreen extends StatefulWidget {
  final Position initialPosition;

  const GameScreen({super.key, required this.initialPosition});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BoardManager _board;
  var _resultShown = false;

  @override
  void initState() {
    super.initState();
    _board = BoardManager(initialPosition: widget.initialPosition);
    _board.addListener(_onBoardChanged);
  }

  @override
  void dispose() {
    _board.removeListener(_onBoardChanged);
    _board.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      body: ListenableBuilder(listenable: _board, builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final bottomSide = _board.flipped ? Side.han : Side.cho;
    return PopScope(
      canPop: _board.isOver,
      onPopInvokedWithResult: _onPopInvoked,
      child: Column(
        children: [
          GameHeader(
            // 개발용 대국 · 4수
            title: l10n.gameDevTitle(_board.moveCount),
            onBack: _onBack,
          ),
          _buildPlayerBar(context, bottomSide.opponent),
          // 판과 아래 정보 줄을 붙여 두고 남는 높이는 버튼 줄 위에 둔다.
          Expanded(
            child: Column(
              children: [
                Flexible(
                  child: BoardView(
                    position: _board.position,
                    flipped: _board.flipped,
                    selected: _board.selected,
                    targets: _board.targets,
                    lastMove: _board.lastMove,
                    dimmedSide: _board.dimmedSide,
                    onSquareTap: _board.tapSquare,
                  ),
                ),
                _buildPlayerBar(context, bottomSide),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: _buildButtonBar(context)),
        ],
      ),
    );
  }

  Widget _buildPlayerBar(BuildContext context, Side side) {
    final l10n = AppLocalizations.of(context);
    return PlayerBar(
      side: side,
      active: !_board.isOver && _board.turn == side,
      // 72점
      detail: l10n.score(formatScore(_board.position.score(side))),
      trailing: [
        if (_board.checkedSide == side)
          PlayerBadge(
            // 장군
            label: l10n.check,
            color: GameColors.background,
            background: GameColors.check,
          ),
        if (_board.hasPassedLast(side))
          PlayerBadge(
            // 한수쉼
            label: l10n.passedLast,
            color: GameColors.subText,
          ),
      ],
    );
  }

  /// 아래쪽 버튼 줄. 테두리 있는 상자로 나누지 않고 한 줄 막대 안에 아이콘과 글자를 담는다.
  Widget _buildButtonBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playing = !_board.isOver;
    return DecoratedBox(
      decoration: BoxDecoration(color: GameColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _BarButton(
                icon: Icons.pause,
                // 한수쉼
                label: l10n.pass,
                onPressed: playing && _board.canPass ? _onPass : null,
              ),
            ),
            Expanded(
              child: _BarButton(
                icon: Icons.more_horiz,
                // 더보기
                label: l10n.more,
                onPressed: playing ? _onMore : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onBoardChanged() {
    if (!_board.isOver || _resultShown) {
      return;
    }
    _resultShown = true;
    _showResult();
  }

  Future<void> _showResult() async {
    final result = _board.result!;
    final action = await showModalBottomSheet<GameResultAction>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (context) =>
          GameResultSheet(result: result, moveCount: _board.moveCount, elapsed: _board.getElapsed(DateTime.now())),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case GameResultAction.rematch:
        Navigator.of(context).pushReplacement(createGameRoute<void>((context) => const SetupScreen()));
      case GameResultAction.home:
        Navigator.of(context).pop();
    }
  }

  void _onPass() {
    try {
      _board.pass();
    } catch (error, stackTrace) {
      developer.log('BoardManager.pass 실패', error: error, stackTrace: stackTrace);
      // 지금은 한수쉼을 할 수 없어요
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).passFailed)));
    }
  }

  Future<void> _onMore() async {
    final action = await showModalBottomSheet<_MenuAction>(context: context, builder: _buildMenu);
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MenuAction.flipBoard:
        _board.toggleFlipped();
      case _MenuAction.resign:
        await _confirmResign();
    }
  }

  Widget _buildMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuItem(
              icon: Icons.sync,
              // 판 돌리기
              label: l10n.flipBoard,
              action: _MenuAction.flipBoard,
            ),
            _MenuItem(
              icon: Icons.flag_outlined,
              // 기권
              label: l10n.resign,
              action: _MenuAction.resign,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResign() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await DialogUtils.showConfirm(
      context,
      // 초가 기권할까요? / 한이 기권할까요?
      message: l10n.resignConfirm(_board.turn.name),
      // 기권하기
      confirmLabel: l10n.resignAction,
    );
    if (!confirmed || !mounted || _board.isOver) {
      return;
    }
    try {
      _board.resign();
    } catch (error, stackTrace) {
      developer.log('BoardManager.resign 실패', error: error, stackTrace: stackTrace);
    }
  }

  void _onBack() {
    Navigator.of(context).maybePop();
  }

  /// 대국 중 뒤로 가기는 한 번 더 확인한 뒤 나간다.
  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await DialogUtils.showConfirm(
      context,
      // 대국을 그만두고 나갈까요?
      message: l10n.leaveGameConfirm,
      // 나가기
      confirmLabel: l10n.leaveGameAction,
    );
    if (!confirmed || !mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

enum _MenuAction { flipBoard, resign }

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final _MenuAction action;

  const _MenuItem({required this.icon, required this.label, required this.action});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: GameColors.text),
      title: Text(
        label,
        style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
      ),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _BarButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? GameColors.inactiveText : GameColors.buttonText;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(minTouchSize, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        foregroundColor: GameColors.buttonText,
        disabledForegroundColor: GameColors.inactiveText,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}
