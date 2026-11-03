import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/board_manager.dart';
import '../managers/chat_manager.dart';
import '../managers/online_game_manager.dart';
import '../models/chat_message.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/game_clock.dart';
import '../utils/game_format.dart';
import '../utils/rank_format.dart';
import '../utils/score_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/chat_view.dart';
import '../widgets/board/board_view.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/player_bar.dart';
import 'game_result_sheet.dart';
import 'quick_match_screen.dart';
import 'review_screen.dart';
import 'room_screen.dart';
import 'setup_screen.dart';

/// 대국 화면. 개발용 대국과 온라인 대국이 같은 화면을 쓰고 모드에 따라 정보 줄과 버튼만 바꾼다(`docs/screens.md`의 대국 화면).
///
/// 개발용 대국([gameId]가 null)은 한 기기에서 양쪽을 두고 초가 아래에 온다. 온라인 대국은 내 진영이 아래이고 내 차례에만 두며,
/// 정보 줄에 닉네임, 급수, 시계를 보여준다. 어느 모드든 차례가 아닌 쪽의 기물을 살짝 어둡게 한다.
class GameScreen extends StatefulWidget {
  /// 개발용 대국의 처음 국면. 온라인 대국이면 null이다.
  final Position? initialPosition;

  /// 온라인 대국 ID. 개발용 대국이면 null이다.
  final String? gameId;

  const GameScreen({super.key, required Position this.initialPosition}) : gameId = null;

  const GameScreen.online({super.key, required String this.gameId}) : initialPosition = null;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  BoardManager? _localBoard;
  OnlineGameManager? _online;
  var _resultShown = false;

  // 온라인 대국의 대국 채팅. 개발용 대국이면 null이다.
  ChatManager? _gameChat;

  // 대국이 끝난 뒤 대국자도 보는 관전 채팅(`docs/moderation.md`의 채팅 종류). 대국 중에는 null이다.
  ChatManager? _spectatorChat;

  @override
  void initState() {
    super.initState();
    final gameId = widget.gameId;
    if (gameId == null) {
      _localBoard = BoardManager(initialPosition: widget.initialPosition!)..addListener(_onBoardChanged);
    } else {
      _online = OnlineGameManager(
        gameId: gameId,
        uid: managers.authManager.uid!,
        connectionManager: managers.connectionManager,
      )..addListener(_onBoardChanged);
      _gameChat = _createChat(ChatChannel.game, gameId);
    }
  }

  @override
  void dispose() {
    _localBoard?.removeListener(_onBoardChanged);
    _localBoard?.dispose();
    _online?.removeListener(_onBoardChanged);
    _online?.dispose();
    _gameChat?.dispose();
    _spectatorChat?.dispose();
    super.dispose();
  }

  ChatManager _createChat(ChatChannel channel, String gameId) => ChatManager(
    channel: channel,
    gameId: gameId,
    authManager: managers.authManager,
    blockManager: managers.blockManager,
  );

  /// 채팅 창에 보여줄 채팅. 개발용 대국이면 비어 있다.
  List<ChatManager> get _chats => [?_gameChat, ?_spectatorChat];

  /// 지금 판. 온라인 대국은 처음 값을 받기 전이면 null이다.
  BoardManager? get _board => _online?.board ?? _localBoard;

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      body: ListenableBuilder(listenable: (_online ?? _localBoard)!, builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final online = _online;
    final board = _board;
    if (online != null && online.loadError != null) {
      // 대국을 불러오지 못했어요
      return _buildMessage(context, l10n.errorGameLoad);
    }
    if (online != null && online.loaded && (online.game == null || online.mySide == null)) {
      // 상대나 대국을 찾지 못했어요
      return _buildMessage(context, l10n.errorGameNotFound);
    }
    if (board == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final bottomSide = board.flipped ? Side.han : Side.cho;
    final game = online?.game;
    // 온라인 대국 · 4수 / 개발용 대국 · 4수
    final title = online != null ? l10n.gameOnlineTitle(board.moveCount) : l10n.gameDevTitle(board.moveCount);
    if (getLayoutSize(context) == LayoutSize.expanded) {
      return PopScope(
        canPop: board.isOver,
        onPopInvokedWithResult: _onPopInvoked,
        child: GameWideLayout(
          onBack: _onBack,
          boardColumn: Column(
            children: [
              _buildPlayerBar(context, board, bottomSide.opponent),
              Flexible(child: _buildBoard(board)),
              _buildPlayerBar(context, board, bottomSide),
            ],
          ),
          panel: GamePanel(
            title: title,
            details: game == null ? const [] : getGameDetails(l10n, game.meta),
            body: _chats.isEmpty ? null : ChatView(chats: _chats, style: ChatStyle.dark),
            buttons: _buildButtonBar(context, board, wide: true),
          ),
        ),
      );
    }
    return PopScope(
      canPop: board.isOver,
      onPopInvokedWithResult: _onPopInvoked,
      child: Column(
        children: [
          GameHeader(title: title, onBack: _onBack),
          _buildPlayerBar(context, board, bottomSide.opponent),
          // 판과 아래 정보 줄을 붙여 두고 남는 높이는 버튼 줄 위에 둔다.
          Expanded(
            child: Column(
              children: [
                Flexible(child: _buildBoard(board)),
                _buildPlayerBar(context, board, bottomSide),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildButtonBar(context, board, wide: false),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(BoardManager board) {
    return Stack(
      alignment: Alignment.center,
      children: [
        BoardView(
          position: board.position,
          flipped: board.flipped,
          selected: board.selected,
          targets: board.targets,
          lastMove: board.lastMove,
          dimmedSide: board.dimmedSide,
          onSquareTap: _onSquareTap,
        ),
        if (_online != null) const ReconnectingNotice(),
      ],
    );
  }

  Widget _buildMessage(BuildContext context, String message) {
    return Column(
      children: [
        GameHeader(title: '', onBack: _onBack),
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

  Widget _buildPlayerBar(BuildContext context, BoardManager board, Side side) {
    final l10n = AppLocalizations.of(context);
    final online = _online;
    final game = online?.game;
    return PlayerBar(
      side: side,
      active: !board.isOver && board.turn == side,
      name: game == null ? null : getPlayerName(l10n, game.meta.players.get(side)),
      // 72점
      detail: l10n.score(formatScore(board.position.score(side))),
      notice: online != null && side != online.mySide ? DisconnectNotice(online: online, side: side) : null,
      trailing: [
        if (board.checkedSide == side)
          PlayerBadge(
            // 장군
            label: l10n.check,
            color: GameColors.background,
            background: GameColors.check,
          ),
        if (board.hasPassedLast(side))
          PlayerBadge(
            // 한수쉼
            label: l10n.passedLast,
            color: GameColors.subText,
          ),
        if (game != null) PlayerClock(online: _online!, side: side),
      ],
    );
  }

  /// 한수쉼, 채팅, 더보기. 넓은 화면 패널([wide])에서는 채팅이 패널 가운데에 있어 빼고, 기권을 더보기 밖에 꺼내 둔다.
  Widget _buildButtonBar(BuildContext context, BoardManager board, {required bool wide}) {
    final l10n = AppLocalizations.of(context);
    final playing = !board.isOver;
    final chats = _chats;
    return GameButtonBar(
      children: [
        GameBarButton(
          icon: Icons.pause,
          // 한수쉼
          label: l10n.pass,
          onPressed: playing && board.canPass ? _onPass : null,
        ),
        if (!wide && chats.isNotEmpty)
          ChatBarButton(
            chats: chats,
            // 채팅
            label: l10n.chat,
          ),
        if (wide)
          GameBarButton(
            icon: Icons.flag_outlined,
            // 기권
            label: l10n.resign,
            onPressed: playing ? _confirmResign : null,
          ),
        GameBarButton(
          icon: Icons.more_horiz,
          // 더보기
          label: l10n.more,
          onPressed: playing ? _onMore : null,
        ),
      ],
    );
  }

  void _onBoardChanged() {
    final board = _board;
    if (board == null || !board.isOver) {
      return;
    }
    final online = _online;
    if (online != null && _spectatorChat == null) {
      _spectatorChat = _createChat(ChatChannel.spectator, online.gameId);
    }
    if (_resultShown) {
      return;
    }
    _resultShown = true;
    _showResult(board);
  }

  Future<void> _showResult(BoardManager board) async {
    final result = board.result!;
    final online = _online;
    final elapsed = online != null ? online.getElapsed() : board.getElapsed(DateTime.now());
    final action = await showGameSheet<GameResultAction>(
      context,
      dismissible: false,
      builder: (context) => GameResultSheet(
        result: result,
        moveCount: board.moveCount,
        elapsed: elapsed,
        online: online,
        chats: online == null ? null : _chats,
      ),
    );
    if (!mounted) {
      return;
    }
    // 온라인 대국은 다시 두기로 새 대국에 묶인 경우 말고는 결과 화면을 나가면서 기다리던 다시 두기를 취소한다.
    // 창을 뒤로 가기로 닫으면 홈으로 간다.
    if (online != null && action != GameResultAction.rematch) {
      unawaited(_leaveResult(online.gameId));
    }
    switch (action) {
      case GameResultAction.playAgain:
        Navigator.of(context).pushReplacement(createGameRoute<void>((context) => const QuickMatchScreen()));
      case GameResultAction.rematch:
        final rematchGameId = online?.game?.rematch?.gameId;
        if (rematchGameId != null) {
          Navigator.of(context)
              .pushReplacement(createGameRoute<void>((context) => SetupScreen.online(gameId: rematchGameId)));
        } else {
          Navigator.of(context).pushReplacement(createGameRoute<void>((context) => const SetupScreen()));
        }
      case GameResultAction.review:
        final record = board.game;
        Navigator.of(context).pushReplacement(createGameRoute<void>((context) => ReviewScreen(record: record)));
      case GameResultAction.home:
      case null:
        // 방 대국은 결과 창을 나가면 홈 대신 방 대기실로 돌아간다(`docs/game/matching.md`의 방 유지).
        final roomId = online?.game?.meta.roomId;
        if (roomId != null) {
          RoomScreen.returnTo(Navigator.of(context), roomId);
        } else {
          Navigator.of(context).pop();
        }
    }
  }

  /// 결과 화면을 나갔다고 대국 서버에 알린다. 실패해도 화면은 넘어가고, 상대의 다시 두기는 서버가 접속 상태로 취소한다.
  Future<void> _leaveResult(String gameId) async {
    try {
      await repositories.gameRepository.leaveResult(gameId);
    } catch (error, stackTrace) {
      developer.log('GameRepository.leaveResult 실패', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _onSquareTap(Square square) async {
    final online = _online;
    if (online == null) {
      _localBoard!.tapSquare(square);
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      await online.tapSquare(square);
    } catch (error, stackTrace) {
      developer.log('OnlineGameManager.tapSquare 실패', error: error, stackTrace: stackTrace);
      // 수를 보내지 못했어요. 판을 서버와 다시 맞췄어요
      _showSnackBar(error, l10n.errorPlayMove);
    }
  }

  Future<void> _onPass() async {
    try {
      final online = _online;
      if (online != null) {
        await online.pass();
      } else {
        _localBoard!.pass();
      }
    } catch (error, stackTrace) {
      developer.log('한수쉼 실패', error: error, stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      // 지금은 한수쉼을 할 수 없어요 / 수를 보내지 못했어요. 판을 서버와 다시 맞췄어요
      _showSnackBar(error, _online != null ? l10n.errorPlayMove : l10n.passFailed);
    }
  }

  void _showSnackBar(Object error, String defaultMessage) {
    if (!mounted) {
      return;
    }
    final message = error is AppException ? error.getMessage(AppLocalizations.of(context)) : defaultMessage;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onMore() async {
    final action = await showGameSheet<_MenuAction>(context, builder: _buildMenu);
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MenuAction.flipBoard:
        _board?.toggleFlipped();
      case _MenuAction.resign:
        await _confirmResign();
    }
  }

  /// 더보기 창. 넓은 화면은 기권이 패널에 따로 있어 판 돌리기만 둔다.
  Widget _buildMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = getLayoutSize(context) == LayoutSize.expanded;
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
            if (!wide)
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
    final board = _board;
    if (board == null) {
      return;
    }
    final online = _online;
    final confirmed = await DialogUtils.showConfirm(
      context,
      // 기권할까요? 이 대국은 지게 돼요 / 초가 기권할까요? / 한이 기권할까요?
      message: online != null ? l10n.resignConfirmOnline : l10n.resignConfirm(board.turn.name),
      // 기권하기
      confirmLabel: l10n.resignAction,
    );
    if (!confirmed || !mounted || board.isOver) {
      return;
    }
    try {
      if (online != null) {
        await online.resign();
      } else {
        board.resign();
      }
    } catch (error, stackTrace) {
      developer.log('기권 실패', error: error, stackTrace: stackTrace);
      // 기권하지 못했어요. 잠시 후 다시 해 주세요
      _showSnackBar(error, l10n.errorResign);
    }
  }

  void _onBack() {
    Navigator.of(context).maybePop();
  }

  /// 대국 중 뒤로 가기는 한 번 더 확인한 뒤 나간다. 온라인 대국은 나가도 대국이 계속된다고 알린다.
  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await DialogUtils.showConfirm(
      context,
      // 화면을 나가도 대국은 계속돼요. 나갈까요? / 대국을 그만두고 나갈까요?
      message: _online != null ? l10n.leaveOnlineGameConfirm : l10n.leaveGameConfirm,
      // 나가기
      confirmLabel: l10n.leaveGameAction,
    );
    if (!confirmed || !mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

/// 온라인 대국 정보 줄의 시계. 서버 시각이 바뀔 때마다 이것만 다시 그린다.
class PlayerClock extends StatelessWidget {
  final OnlineGameManager online;
  final Side side;

  const PlayerClock({super.key, required this.online, required this.side});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(valueListenable: online.serverNow, builder: _buildClock);
  }

  Widget _buildClock(BuildContext context, int nowMs, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final game = online.game;
    if (game == null) {
      return const SizedBox.shrink();
    }
    final clock = getClockDisplay(game, side, nowMs);
    final period = clock.period;
    return ClockBadge(
      time: formatClock(period ?? clock.base),
      // 초읽기 3회
      periods: l10n.clockPeriods(clock.periods),
      warning: period != null,
      running: game.state.endedAt == null && game.state.turn == side,
    );
  }
}

/// 상대 연결이 끊긴 동안 상대 정보 줄에 "연결이 끊겼어요"와 이번 대국에서 남은 끊김 허용 시간을 보여준다
/// (`docs/screens.md`의 대국 화면). 서버가 끊긴 것으로 기록한 동안만 보이고, 서버 시각이 바뀔 때마다 이것만 다시 그린다.
class DisconnectNotice extends StatelessWidget {
  final OnlineGameManager online;
  final Side side;

  const DisconnectNotice({super.key, required this.online, required this.side});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(valueListenable: online.serverNow, builder: _buildNotice);
  }

  Widget _buildNotice(BuildContext context, int nowMs, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final game = online.game;
    final remaining = game == null ? null : getDisconnectRemaining(game, side, nowMs);
    if (remaining == null) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off, size: 18, color: GameColors.check),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            // 연결이 끊겼어요 25초
            l10n.opponentDisconnected((remaining.inMilliseconds / 1000).ceil()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTextSizes.body,
              fontWeight: FontWeight.w700,
              color: GameColors.check,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// 내 기기가 RTDB에서 끊긴 동안 판 위에 "다시 연결하는 중"을 보여준다. 다시 연결되면 대국은 같은 화면에서 이어진다.
class ReconnectingNotice extends StatelessWidget {
  const ReconnectingNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: managers.connectionManager, builder: _buildNotice);
  }

  Widget _buildNotice(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    if (managers.connectionManager.connected) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(color: GameColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 12),
          Text(
            // 다시 연결하는 중
            l10n.reconnecting,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700, color: GameColors.text),
          ),
        ],
      ),
    );
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
