import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/online_game_manager.dart';
import '../managers/setup_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/game_clock.dart';
import '../utils/rank_format.dart';
import '../widgets/board/board_geometry.dart';
import '../widgets/board/board_view.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/piece_icon.dart';
import '../widgets/player_bar.dart';
import 'game_screen.dart';

/// 상차림 화면. 한이 먼저 고르고 초는 한이 확정한 뒤 고른다(`docs/game/rules.md`).
///
/// 개발용 대국([gameId]가 null)은 한 기기에서 한이 먼저 고르고 이어서 초가 고른다. 상차림 버튼의 기물 순서가 고르는 사람 기준
/// 왼쪽부터이므로 고르는 쪽이 아래에 오도록 판을 돌린다. 온라인 대국은 내 진영이 아래이고 서버가 정한 차례와 마감을 따른다.
/// 상차림이 끝나면 대국 화면으로 넘어간다.
class SetupScreen extends StatefulWidget {
  /// 온라인 대국 ID. null이면 한 기기에서 양쪽을 고르는 개발용 대국이다.
  final String? gameId;

  const SetupScreen({super.key}) : gameId = null;

  const SetupScreen.online({super.key, required String this.gameId});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  SetupManager? _setup;
  OnlineGameManager? _online;

  // 대국 화면으로 넘어가기 시작했다. 서버 상태가 또 바뀌어도 다시 넘어가지 않는다.
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    final gameId = widget.gameId;
    if (gameId == null) {
      _setup = SetupManager()..addListener(_onSetupChanged);
    } else {
      _online = OnlineGameManager(
        gameId: gameId,
        uid: managers.authManager.uid!,
        connectionManager: managers.connectionManager,
      )..addListener(_onOnlineChanged);
    }
  }

  @override
  void dispose() {
    _setup?.removeListener(_onSetupChanged);
    _setup?.dispose();
    _online?.removeListener(_onOnlineChanged);
    _online?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = _online;
    return GameScaffold(
      body: online != null
          ? ListenableBuilder(listenable: online, builder: _buildOnlineBody)
          : ListenableBuilder(listenable: _setup!, builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final setup = _setup!;
    final chooser = setup.chooser;
    final flipped = chooser == Side.han;
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
          trailing: [
            if (chooser == Side.cho)
              _buildDecidedBadge(
                context,
                squares: setup.getFormationSquares(chooser.opponent),
                position: setup.preview,
                flipped: flipped,
              ),
          ],
        ),
        // 판, 고르는 쪽 정보 줄, 상차림 버튼을 붙여 두고 남는 높이는 정하기 버튼 위에 둔다.
        Expanded(
          child: Column(
            children: [
              Flexible(
                child: BoardView(
                  position: setup.preview,
                  flipped: flipped,
                  highlighted: setup.getFormationSquares(chooser),
                ),
              ),
              PlayerBar(side: chooser, active: true),
              _buildFormationGrid(context, side: chooser, picked: setup.picked, onPick: setup.pick),
            ],
          ),
        ),
        _buildConfirmButton(
          // 이 상차림으로 정하기
          label: l10n.setupConfirm,
          onPressed: _onConfirm,
        ),
      ],
    );
  }

  Widget _buildOnlineBody(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final online = _online!;
    final game = online.game;
    final mySide = online.mySide;
    if (online.loadError != null) {
      // 대국을 불러오지 못했어요
      return _buildMessage(context, l10n.errorGameLoad);
    }
    if (!online.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (game == null || mySide == null) {
      // 상대나 대국을 찾지 못했어요
      return _buildMessage(context, l10n.errorGameNotFound);
    }
    final opponentSide = mySide.opponent;
    final setupTurn = online.setupTurn;
    final flipped = mySide == Side.han;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Column(
        children: [
          GameHeader(
            // 상차림을 골라 주세요
            title: l10n.setupTitle,
            onBack: _onBack,
          ),
          PlayerBar(
            side: opponentSide,
            active: setupTurn == opponentSide,
            name: getPlayerName(l10n, game.meta.players.get(opponentSide)),
            notice: DisconnectNotice(online: online, side: opponentSide),
            trailing: [
              if (online.hasConfirmedFormation(opponentSide))
                _buildDecidedBadge(
                  context,
                  squares: online.getFormationSquares(opponentSide),
                  position: online.setupPreview,
                  flipped: flipped,
                ),
              if (setupTurn == opponentSide) _buildSetupTimer(online),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                Flexible(
                  child: BoardView(
                    position: online.setupPreview,
                    flipped: flipped,
                    highlighted: online.getFormationSquares(mySide),
                  ),
                ),
                PlayerBar(
                  side: mySide,
                  active: setupTurn == mySide,
                  name: getPlayerName(l10n, game.meta.players.get(mySide)),
                  trailing: [if (setupTurn == mySide) _buildSetupTimer(online)],
                ),
                _buildFormationGrid(
                  context,
                  side: mySide,
                  picked: online.picked,
                  onPick: online.canPickFormation ? _onPickOnline : null,
                ),
              ],
            ),
          ),
          _buildConfirmButton(
            // 상대가 고르고 있어요 / 이 상차림으로 정하기
            label: setupTurn == opponentSide ? l10n.setupOpponentChoosing : l10n.setupConfirm,
            onPressed: online.canPickFormation ? _onConfirmOnline : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(BuildContext context, String message) {
    return Column(
      children: [
        GameHeader(title: '', onBack: _onBackWithoutConfirm),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 지금 고르는 쪽의 남은 상차림 시간. 서버 시각이 바뀔 때마다 이것만 다시 그린다.
  Widget _buildSetupTimer(OnlineGameManager online) {
    return ValueListenableBuilder<int>(valueListenable: online.serverNow, builder: _buildSetupTimerBadge);
  }

  Widget _buildSetupTimerBadge(BuildContext context, int nowMs, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final game = _online?.game;
    final remaining = game == null ? null : getSetupRemaining(game, nowMs);
    if (remaining == null) {
      return const SizedBox.shrink();
    }
    return PlayerBadge(
      // 20초
      label: l10n.setupSeconds((remaining.inMilliseconds / 1000).ceil()),
      color: remaining.inSeconds < 5 ? GameColors.check : GameColors.buttonText,
    );
  }

  /// 상대가 정한 마·상 네 개를 화면에 놓인 순서대로 보여준다.
  Widget _buildDecidedBadge(
    BuildContext context, {
    required Set<Square> squares,
    required Position position,
    required bool flipped,
  }) {
    final l10n = AppLocalizations.of(context);
    final geometry = BoardGeometry(Size.zero, flipped: flipped);
    final ordered = squares.toList()..sort((a, b) => geometry.columnOf(a).compareTo(geometry.columnOf(b)));
    return PlayerBadge(
      // 정했어요
      label: l10n.setupDecided,
      color: GameColors.buttonText,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: GameColors.accent, size: 20),
          const SizedBox(width: 4),
          for (final square in ordered) PieceIcon(piece: position.pieceAt(square)!, size: 24),
        ],
      ),
    );
  }

  /// 네 가지 상차림 버튼(2×2). [onPick]이 null이면 누를 수 없다.
  Widget _buildFormationGrid(
    BuildContext context, {
    required Side side,
    required Formation picked,
    required ValueChanged<Formation>? onPick,
  }) {
    return Padding(
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
                    Expanded(
                      child: _FormationButton(
                        formation: Formation.values[row * 2 + column],
                        side: side,
                        selected: Formation.values[row * 2 + column] == picked,
                        onPick: onPick,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton({required String label, required VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }

  void _onSetupChanged() {
    final setup = _setup!;
    if (!setup.isDone) {
      return;
    }
    final initialPosition = setup.initialPosition;
    Navigator.of(context)
        .pushReplacement(createGameRoute<void>((context) => GameScreen(initialPosition: initialPosition)));
  }

  /// 상차림이 끝나면(상차림 중 기권으로 끝난 경우 포함) 대국 화면으로 넘어간다.
  void _onOnlineChanged() {
    final online = _online!;
    final phase = online.phase;
    if (_leaving || phase == null || online.setupTurn != null) {
      return;
    }
    _leaving = true;
    final gameId = online.gameId;
    Navigator.of(context).pushReplacement(createGameRoute<void>((context) => GameScreen.online(gameId: gameId)));
  }

  void _onConfirm() {
    _setup!.confirm();
  }

  Future<void> _onPickOnline(Formation formation) async {
    try {
      await _online!.pickFormation(formation);
    } catch (error, stackTrace) {
      developer.log('OnlineGameManager.pickFormation 실패', error: error, stackTrace: stackTrace);
      _showError(error);
    }
  }

  Future<void> _onConfirmOnline() async {
    try {
      await _online!.confirmFormation();
    } catch (error, stackTrace) {
      developer.log('OnlineGameManager.confirmFormation 실패', error: error, stackTrace: stackTrace);
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    // 상차림을 보내지 못했어요. 잠시 후 다시 해 주세요
    final message = error is AppException ? error.getMessage(l10n) : l10n.errorSetFormation;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onBack() {
    Navigator.of(context).maybePop();
  }

  void _onBackWithoutConfirm() {
    Navigator.of(context).pop();
  }

  /// 온라인 대국의 뒤로 가기는 대국이 계속된다는 것을 알리고 확인을 받은 뒤 나간다.
  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await DialogUtils.showConfirm(
      context,
      // 화면을 나가도 대국은 계속돼요. 나갈까요?
      message: l10n.leaveOnlineGameConfirm,
      // 나가기
      confirmLabel: l10n.leaveGameAction,
    );
    if (!confirmed || !mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

/// 상차림 버튼. 글자 없이 마·상 기물 네 개를 고르는 사람 기준 왼쪽부터 놓고, 화면 읽기용 이름을 둔다.
class _FormationButton extends StatelessWidget {
  final Formation formation;
  final Side side;
  final bool selected;

  /// null이면 누를 수 없다.
  final ValueChanged<Formation>? onPick;

  const _FormationButton({required this.formation, required this.side, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onPick = this.onPick;
    return Semantics(
      // 마상마상 / 상마상마 / 마상상마 / 상마마상
      label: l10n.formationName(formation.name),
      selected: selected,
      button: true,
      enabled: onPick != null,
      excludeSemantics: true,
      child: Material(
        color: selected ? GameColors.accentSurface : GameColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? GameColors.accent : Colors.transparent, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPick == null ? null : _onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final type in formation.pieces)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: PieceIcon(piece: Piece(side, type), size: 36),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap() {
    onPick?.call(formation);
  }
}
