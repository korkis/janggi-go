import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/online_game_manager.dart';
import '../managers/setup_manager.dart';
import '../models/game_enums.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/game_clock.dart';
import '../utils/game_format.dart';
import '../utils/rank_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/board/board_geometry.dart';
import '../widgets/board/board_view.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/piece_icon.dart';
import '../widgets/player_bar.dart';
import 'game_screen.dart';
import 'review_screen.dart';

/// 상차림 화면. 한이 먼저 고르고 초는 한이 확정한 뒤 고른다(`docs/game/rules.md`).
///
/// 개발용 대국([gameId]가 null)과 새 판에서 놓아보기([freePlay])는 한 기기에서 한이 먼저 고르고 이어서 초가 고른다. 상차림 버튼의 기물 순서가 고르는 사람 기준
/// 왼쪽부터이므로 고르는 쪽이 아래에 오도록 판을 돌린다. 온라인 대국은 내 진영이 아래이고 서버가 정한 차례와 마감을 따른다.
/// 상차림은 판 위에 띄운 상차림 창에서 고르고(`docs/screens.md`의 상차림), 끝나면 대국 화면으로 넘어간다. 새 판에서 놓아보기는
/// 대국 화면 대신 놓아보기를 켠 복기 화면으로 넘어간다.
class SetupScreen extends StatefulWidget {
  /// 온라인 대국 ID. null이면 한 기기에서 양쪽을 고르는 개발용 대국이나 새 판에서 놓아보기다.
  final String? gameId;

  /// 새 판에서 놓아보기(`docs/screens.md`의 내 기보 목록). 양쪽을 자유롭게 두는 연구용 판이다.
  final bool freePlay;

  /// 새 판에서 놓아보기의 접장기로 한에서 뗄 기물.
  final Set<HandicapPiece> hanRemoved;

  const SetupScreen({super.key}) : gameId = null, freePlay = false, hanRemoved = const {};

  const SetupScreen.online({super.key, required String this.gameId}) : freePlay = false, hanRemoved = const {};

  const SetupScreen.freePlay({super.key, this.hanRemoved = const {}}) : gameId = null, freePlay = true;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  SetupManager? _setup;
  OnlineGameManager? _online;

  // 대국 화면으로 넘어가기 시작했다. 서버 상태가 또 바뀌어도 다시 넘어가지 않는다.
  var _leaving = false;

  // 판 자리를 재서 상차림 창과 끊김 카드를 그 위에 띄운다.
  final _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final gameId = widget.gameId;
    if (gameId == null) {
      _setup = SetupManager(hanRemoved: widget.hanRemoved)..addListener(_onSetupChanged);
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
    final opponent = chooser.opponent;
    final flipped = chooser == Side.han;
    return _buildFrame(
      context,
      onBack: _onBack,
      layout: _SetupLayout(
        opponentBar: PlayerBar(side: opponent, active: false),
        board: KeyedSubtree(
          key: _boardKey,
          child: BoardView(
            materials: managers.storeManager.materials,
            position: setup.preview,
            flipped: flipped,
            highlighted: setup.getFormationSquares(chooser),
          ),
        ),
        myBar: PlayerBar(side: chooser, active: true),
      ),
      dialog: _SetupDialog(
        opponentSide: opponent,
        // 한 / 초
        opponentName: l10n.sideName(opponent.name),
        mySide: chooser,
        timer: null,
        decided: chooser == Side.cho
            ? _getOrderedPieces(setup.getFormationSquares(opponent), setup.preview, flipped: flipped)
            : null,
        opponentChoosing: false,
        opponentMaterial: managers.storeManager.selectedMaterial,
        grid: _buildFormationGrid(
          context,
          side: chooser,
          material: managers.storeManager.selectedMaterial,
          picked: setup.picked,
          onPick: setup.pick,
        ),
        onConfirm: _onConfirm,
      ),
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
    final myConfirmed = online.hasConfirmedFormation(mySide);
    // 온라인 대국은 상차림부터 나갈 수 없어 뒤로 버튼도 두지 않는다(`docs/screens.md`의 대국 화면).
    return PopScope(
      canPop: false,
      child: _buildFrame(
        context,
        onBack: null,
        details: getGameDetails(l10n, game.meta),
        layout: _SetupLayout(
          opponentBar: PlayerBar(
            side: opponentSide,
            active: setupTurn == opponentSide,
            name: getPlayerName(l10n, game.meta.players.get(opponentSide)),
            trailing: [if (setupTurn == opponentSide) _buildSetupTimer(online)],
          ),
          board: KeyedSubtree(
            key: _boardKey,
            child: BoardView(
              materials: game.meta.players.materials,
              position: online.setupPreview,
              flipped: flipped,
              highlighted: online.getFormationSquares(mySide),
            ),
          ),
          myBar: PlayerBar(
            side: mySide,
            active: setupTurn == mySide,
            name: getPlayerName(l10n, game.meta.players.get(mySide)),
          ),
          notice: myConfirmed ? const _WaitingNotice() : null,
        ),
        // 확정한 뒤에는 창을 닫고 판 위에 안내만 둔다.
        dialog: myConfirmed
            ? null
            : _SetupDialog(
                opponentSide: opponentSide,
                opponentName: getPlayerName(l10n, game.meta.players.get(opponentSide)),
                mySide: mySide,
                timer: _buildSetupTimer(online),
                decided: online.hasConfirmedFormation(opponentSide)
                    ? _getOrderedPieces(online.getFormationSquares(opponentSide), online.setupPreview, flipped: flipped)
                    : null,
                opponentChoosing: setupTurn == opponentSide,
                opponentMaterial: game.meta.players.get(opponentSide).pieceMaterial ?? PieceMaterial.plastic,
                grid: _buildFormationGrid(
                  context,
                  side: mySide,
                  material: game.meta.players.get(mySide).pieceMaterial ?? PieceMaterial.plastic,
                  picked: online.picked,
                  onPick: online.canPickFormation ? _onPickOnline : null,
                ),
                onConfirm: online.canPickFormation ? _onConfirmOnline : null,
              ),
        disconnect: DisconnectCard(online: online, side: opponentSide),
      ),
    );
  }

  /// 제목 줄과 상차림 자리. 1024 이상은 대국 화면처럼 판 영역과 오른쪽 패널로 나누고 상차림 창은 판 위에 그대로 띄운다.
  ///
  /// 상차림 창([dialog])이 있으면 화면 전체를 어둡게 깔고 그 위에 창을 띄운다(`docs/screens.md`의 상차림). 창은 판의 내 쪽
  /// 마·상 줄을 가리지 않게 그 줄 바로 위에 놓는다. 상대 연결이 끊긴 동안([disconnect])은 판 가운데에 끊김 카드를 띄운다.
  Widget _buildFrame(
    BuildContext context, {
    required VoidCallback? onBack,
    required Widget layout,
    List<String> details = const [],
    Widget? dialog,
    Widget? disconnect,
  }) {
    final l10n = AppLocalizations.of(context);
    final Widget frame;
    if (getLayoutSize(context) == LayoutSize.expanded) {
      frame = GameWideLayout(
        onBack: onBack,
        boardColumn: layout,
        panel: GamePanel(
          // 상차림을 골라 주세요
          title: l10n.setupTitle,
          details: details,
        ),
      );
    } else {
      frame = Column(
        children: [
          GameHeader(
            // 상차림을 골라 주세요
            title: l10n.setupTitle,
            onBack: onBack,
          ),
          Expanded(child: layout),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        frame,
        // 개발용 상차림의 뒤로 버튼은 막 아래에서도 누를 수 있게 둔다.
        if (dialog != null) const IgnorePointer(child: ColoredBox(color: GameColors.scrim)),
        _BoardOverlay(boardKey: _boardKey, dialog: dialog, disconnect: disconnect),
      ],
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
    final color = remaining.inSeconds < 5 ? GameColors.check : GameColors.buttonText;
    return PlayerBadge(
      // 20초
      label: l10n.setupSeconds((remaining.inMilliseconds / 1000).ceil()),
      color: color,
      leading: Icon(Icons.timer_outlined, size: 20, color: color),
    );
  }

  /// [squares]의 기물을 화면에 놓인 순서(왼쪽부터)대로 늘어놓는다.
  List<Piece> _getOrderedPieces(Set<Square> squares, Position position, {required bool flipped}) {
    final geometry = BoardGeometry(Size.zero, flipped: flipped);
    final ordered = squares.toList()..sort((a, b) => geometry.columnOf(a).compareTo(geometry.columnOf(b)));
    return [for (final square in ordered) position.pieceAt(square)!];
  }

  /// 네 가지 상차림 버튼(2×2). [onPick]이 null이면 누를 수 없다.
  Widget _buildFormationGrid(
    BuildContext context, {
    required Side side,
    required PieceMaterial material,
    required Formation picked,
    required ValueChanged<Formation>? onPick,
  }) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 8),
            child: Row(
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _FormationButton(
                      formation: Formation.values[row * 2 + column],
                      side: side,
                      material: material,
                      selected: Formation.values[row * 2 + column] == picked,
                      onPick: onPick,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _onSetupChanged() {
    final setup = _setup!;
    if (!setup.isDone) {
      return;
    }
    final initialPosition = setup.initialPosition;
    if (widget.freePlay) {
      // 놓아보기
      final title = AppLocalizations.of(context).reviewTrial;
      Navigator.of(context).pushReplacement(
        createGameRoute<void>(
          (context) => ReviewScreen(record: Game.start(initialPosition), title: title, trying: true),
        ),
      );
      return;
    }
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
}

/// 상차림 화면의 자리. 대국 화면처럼 상대 정보 줄, 판, 내 정보 줄을 놓는다. 어둡게 까는 막과 상차림 창은 [_BoardOverlay]가
/// 화면 전체 위에 올린다.
class _SetupLayout extends StatelessWidget {
  final Widget opponentBar;
  final Widget board;
  final Widget myBar;

  /// 창을 닫은 뒤 판 가운데에 띄우는 안내.
  final Widget? notice;

  const _SetupLayout({required this.opponentBar, required this.board, required this.myBar, this.notice});

  @override
  Widget build(BuildContext context) {
    final notice = this.notice;
    return CustomMultiChildLayout(
      delegate: _SetupLayoutDelegate(),
      children: [
        LayoutId(id: _SetupSlot.opponentBar, child: opponentBar),
        LayoutId(id: _SetupSlot.board, child: board),
        LayoutId(id: _SetupSlot.myBar, child: myBar),
        if (notice != null) LayoutId(id: _SetupSlot.notice, child: notice),
      ],
    );
  }
}

enum _SetupSlot { opponentBar, board, myBar, notice }

/// 정보 줄 사이에 판을 가장 크게 놓는다.
class _SetupLayoutDelegate extends MultiChildLayoutDelegate {
  static const _gap = 8.0;

  @override
  void performLayout(Size size) {
    final barConstraints = BoxConstraints(minWidth: size.width, maxWidth: size.width, maxHeight: size.height);
    final opponentBarHeight = layoutChild(_SetupSlot.opponentBar, barConstraints).height;
    final myBarHeight = layoutChild(_SetupSlot.myBar, barConstraints).height;
    final boardMaxHeight = max(0.0, size.height - opponentBarHeight - myBarHeight);
    final boardWidth = min(size.width, boardMaxHeight * BoardGeometry.aspectRatio);
    final boardSize = Size(boardWidth, boardWidth / BoardGeometry.aspectRatio);
    layoutChild(_SetupSlot.board, BoxConstraints.tight(boardSize));
    positionChild(_SetupSlot.opponentBar, Offset.zero);
    positionChild(_SetupSlot.board, Offset((size.width - boardSize.width) / 2, opponentBarHeight));
    positionChild(_SetupSlot.myBar, Offset(0, opponentBarHeight + boardSize.height));
    if (hasChild(_SetupSlot.notice)) {
      final noticeSize = layoutChild(
        _SetupSlot.notice,
        BoxConstraints(maxWidth: max(0.0, size.width - _gap * 4), maxHeight: boardSize.height),
      );
      positionChild(
        _SetupSlot.notice,
        Offset((size.width - noticeSize.width) / 2, opponentBarHeight + (boardSize.height - noticeSize.height) / 2),
      );
    }
  }

  @override
  bool shouldRelayout(_SetupLayoutDelegate oldDelegate) => false;
}

/// 화면 전체를 덮는 막 위에 판 자리에 맞춰 띄우는 상차림 창과 상대 연결 끊김 카드.
///
/// 판은 화면 틀 안에 있으므로 [boardKey]로 판의 자리를 잰다. 처음 그린 뒤와 화면이 바뀔 때마다 다시 잰다.
class _BoardOverlay extends StatefulWidget {
  final GlobalKey boardKey;
  final Widget? dialog;
  final Widget? disconnect;

  const _BoardOverlay({required this.boardKey, required this.dialog, required this.disconnect});

  @override
  State<_BoardOverlay> createState() => _BoardOverlayState();
}

class _BoardOverlayState extends State<_BoardOverlay> {
  // 이 위젯 기준의 판 자리. 아직 재지 않았으면 null이다.
  Rect? _boardRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void didUpdateWidget(_BoardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  Widget build(BuildContext context) {
    final boardRect = _boardRect;
    final dialog = widget.dialog;
    final disconnect = widget.disconnect;
    if (boardRect == null) {
      return const SizedBox.shrink();
    }
    return CustomMultiChildLayout(
      delegate: _BoardOverlayDelegate(boardRect),
      children: [
        if (dialog != null) LayoutId(id: _OverlaySlot.dialog, child: dialog),
        if (disconnect != null) LayoutId(id: _OverlaySlot.disconnect, child: disconnect),
      ],
    );
  }

  void _measure(Duration timeStamp) {
    if (!mounted) {
      return;
    }
    final board = widget.boardKey.currentContext?.findRenderObject() as RenderBox?;
    final own = context.findRenderObject() as RenderBox?;
    if (board == null || own == null || !board.hasSize || !own.hasSize) {
      return;
    }
    final rect = own.globalToLocal(board.localToGlobal(Offset.zero)) & board.size;
    if (rect == _boardRect) {
      return;
    }
    setState(() {
      _boardRect = rect;
    });
  }
}

enum _OverlaySlot { dialog, disconnect }

/// 상차림 창은 판 아래쪽 내 마·상 줄 바로 위에, 끊김 카드는 판 위에 놓는다.
class _BoardOverlayDelegate extends MultiChildLayoutDelegate {
  /// 판 아래 끝에서 이만큼(칸 크기의 배수) 위까지는 창으로 덮지 않는다. 내 쪽 마·상 줄과 금빛 표시가 들어간다.
  static const _uncoveredCells = 2.0;

  /// 상차림 창의 가장 넓은 너비.
  static const _dialogMaxWidth = 440.0;

  static const _gap = 8.0;

  final Rect boardRect;

  _BoardOverlayDelegate(this.boardRect);

  @override
  void performLayout(Size size) {
    if (hasChild(_OverlaySlot.dialog)) {
      final cell = boardRect.width / BoardGeometry.widthCells;
      final coveredBottom = max(0.0, boardRect.bottom - cell * _uncoveredCells);
      final dialogSize = layoutChild(
        _OverlaySlot.dialog,
        BoxConstraints(
          maxWidth: max(0.0, min(size.width - _gap * 2, _dialogMaxWidth)),
          maxHeight: max(0.0, coveredBottom - _gap * 2),
        ),
      );
      // 창을 내 쪽 마·상 줄 바로 위에 붙여 고른 상차림이 판에 놓이는 모습을 가까이 보여준다.
      final left = (boardRect.center.dx - dialogSize.width / 2)
          .clamp(_gap, max(_gap, size.width - dialogSize.width))
          .toDouble();
      positionChild(_OverlaySlot.dialog, Offset(left, max(_gap, coveredBottom - _gap - dialogSize.height)));
    }
    if (hasChild(_OverlaySlot.disconnect)) {
      layoutChild(_OverlaySlot.disconnect, BoxConstraints.tight(boardRect.size));
      positionChild(_OverlaySlot.disconnect, boardRect.topLeft);
    }
  }

  @override
  bool shouldRelayout(_BoardOverlayDelegate oldDelegate) => oldDelegate.boardRect != boardRect;
}

/// 상차림 창. 상대 닉네임과 급수, 내 진영, 남은 시간, 상대가 정한 상차림, 상차림 버튼과 정하기 버튼을 둔다.
class _SetupDialog extends StatelessWidget {
  final Side opponentSide;
  final String opponentName;
  final Side mySide;

  /// 남은 상차림 시간. null이면 보여주지 않는다(개발용 대국).
  final Widget? timer;

  /// 상대가 정한 마·상 기물 네 개(화면에 놓인 순서). 상대가 아직 정하지 않았으면 null.
  final List<Piece>? decided;

  /// 상대가 먼저 고르는 중이라 아직 고를 수 없다.
  final bool opponentChoosing;

  /// [decided]를 그릴 상대의 재질.
  final PieceMaterial opponentMaterial;

  final Widget grid;

  /// null이면 누를 수 없다.
  final VoidCallback? onConfirm;

  const _SetupDialog({
    required this.opponentSide,
    required this.opponentName,
    required this.mySide,
    required this.timer,
    required this.decided,
    required this.opponentChoosing,
    required this.opponentMaterial,
    required this.grid,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timer = this.timer;
    final decided = this.decided;
    return Material(
      color: GameColors.surface,
      elevation: 6,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SideAvatar(side: opponentSide, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    opponentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTextSizes.title,
                      fontWeight: FontWeight.w800,
                      color: GameColors.text,
                    ),
                  ),
                ),
                ?timer,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // 나는 초 · 먼저 둬요 / 나는 한 · 나중에 둬요
              l10n.setupMySide(mySide.name),
              style: const TextStyle(
                fontSize: AppTextSizes.body,
                fontWeight: FontWeight.w700,
                color: GameColors.accent,
              ),
            ),
            if (decided != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check, color: GameColors.accent, size: 20),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      // 상대가 정했어요
                      l10n.setupDecided,
                      style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.buttonText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final piece in decided) PieceIcon(piece: piece, size: 28, material: opponentMaterial),
                ],
              ),
            ] else if (opponentChoosing) ...[
              const SizedBox(height: 8),
              Text(
                // 상대가 상차림을 고르고 있어요
                l10n.setupOpponentChoosing,
                style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
              ),
            ],
            const SizedBox(height: 14),
            grid,
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onConfirm,
              // 이 상차림으로 정하기
              child: Text(l10n.setupConfirm),
            ),
          ],
        ),
      ),
    );
  }
}

/// 내 상차림을 확정한 뒤 상대를 기다리는 동안 판 위에 띄우는 안내.
class _WaitingNotice extends StatelessWidget {
  const _WaitingNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              // 상대가 상차림을 고르고 있어요
              l10n.setupOpponentChoosing,
              style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700, color: GameColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상차림 버튼. 글자 없이 마·상 기물 네 개를 고르는 사람 기준 왼쪽부터 놓고, 화면 읽기용 이름을 둔다.
/// 기물 그림은 좁은 화면에서 버튼 폭에 맞춰 줄어든다.
class _FormationButton extends StatelessWidget {
  /// 기물 그림의 가장 큰 크기.
  static const _maxPieceSize = 34.0;

  /// 기물 그림의 좌우 여백.
  static const _pieceGap = 2.0;

  final Formation formation;
  final Side side;
  final PieceMaterial material;
  final bool selected;

  /// null이면 누를 수 없다.
  final ValueChanged<Formation>? onPick;

  const _FormationButton({
    required this.formation,
    required this.side,
    required this.material,
    required this.selected,
    required this.onPick,
  });

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
        color: selected ? GameColors.accentSurface : GameColors.raisedButton,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? GameColors.accent : Colors.transparent, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPick == null ? null : _onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: LayoutBuilder(builder: _buildPieces),
          ),
        ),
      ),
    );
  }

  Widget _buildPieces(BuildContext context, BoxConstraints constraints) {
    final pieces = formation.pieces;
    final fitted = constraints.maxWidth / pieces.length - _pieceGap * 2;
    final size = min(_maxPieceSize, fitted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final type in pieces)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pieceGap),
            child: PieceIcon(piece: Piece(side, type), size: size, material: material),
          ),
      ],
    );
  }

  void _onTap() {
    onPick?.call(formation);
  }
}
