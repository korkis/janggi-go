import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/setup_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/board/board_geometry.dart';
import '../widgets/board/board_view.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/piece_icon.dart';
import '../widgets/player_bar.dart';
import 'game_screen.dart';

/// 상차림 화면. 한 기기에서 한이 먼저 고르고 이어서 초가 고른다.
///
/// 고르는 쪽이 아래에 오도록 판을 돌려 보여준다. 상차림 버튼의 기물 순서가 고르는 사람 기준 왼쪽부터이기 때문이다.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _setup = SetupManager();

  @override
  void initState() {
    super.initState();
    _setup.addListener(_onSetupChanged);
  }

  @override
  void dispose() {
    _setup.removeListener(_onSetupChanged);
    _setup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      body: ListenableBuilder(listenable: _setup, builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final chooser = _setup.chooser;
    return Column(
      children: [
        GameHeader(
          // 상차림을 골라 주세요
          title: l10n.setupTitle,
          onBack: _onBack,
        ),
        PlayerBar(
          side: chooser.opponent,
          active: false,
          trailing: [if (chooser == Side.cho) _buildDecidedBadge(context)],
        ),
        // 판, 고르는 쪽 정보 줄, 상차림 버튼을 붙여 두고 남는 높이는 정하기 버튼 위에 둔다.
        Expanded(
          child: Column(
            children: [
              Flexible(
                child: BoardView(
                  position: _setup.preview,
                  flipped: chooser == Side.han,
                  highlighted: _setup.getFormationSquares(chooser),
                ),
              ),
              PlayerBar(side: chooser, active: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  children: [
                    for (var row = 0; row < 2; row++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            for (var column = 0; column < 2; column++) ...[
                              if (column > 0) const SizedBox(width: 8),
                              Expanded(child: _buildFormationButton(context, Formation.values[row * 2 + column])),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _onConfirm,
              // 이 상차림으로 정하기
              child: Text(l10n.setupConfirm),
            ),
          ),
        ),
      ],
    );
  }

  /// 상대가 정한 마·상 네 개를 화면에 놓인 순서대로 보여준다.
  Widget _buildDecidedBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final side = _setup.chooser.opponent;
    final geometry = BoardGeometry(Size.zero, flipped: _setup.chooser == Side.han);
    final squares = _setup.getFormationSquares(side).toList()
      ..sort((a, b) => geometry.columnOf(a).compareTo(geometry.columnOf(b)));
    final position = _setup.preview;
    return PlayerBadge(
      // 정했어요
      label: l10n.setupDecided,
      color: GameColors.buttonText,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: GameColors.accent, size: 20),
          const SizedBox(width: 4),
          for (final square in squares) PieceIcon(piece: position.pieceAt(square)!, size: 24),
        ],
      ),
    );
  }

  Widget _buildFormationButton(BuildContext context, Formation formation) {
    final l10n = AppLocalizations.of(context);
    final selected = formation == _setup.picked;
    return Semantics(
      // 마상마상 / 상마상마 / 마상상마 / 상마마상
      label: l10n.formationName(formation.name),
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: selected ? GameColors.accentSurface : GameColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? GameColors.accent : Colors.transparent, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _setup.pick(formation),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final type in formation.pieces)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: PieceIcon(piece: Piece(_setup.chooser, type), size: 36),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSetupChanged() {
    if (!_setup.isDone) {
      return;
    }
    final initialPosition = _setup.initialPosition;
    Navigator.of(context)
        .pushReplacement(createGameRoute<void>((context) => GameScreen(initialPosition: initialPosition)));
  }

  void _onConfirm() {
    _setup.confirm();
  }

  void _onBack() {
    Navigator.of(context).pop();
  }
}
