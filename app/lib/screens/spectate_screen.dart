import 'dart:math';

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/board_manager.dart';
import '../managers/chat_manager.dart';
import '../managers/online_game_manager.dart';
import '../managers/spectate_manager.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import '../utils/game_format.dart';
import '../utils/rank_format.dart';
import '../utils/score_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/board/board_view.dart';
import '../widgets/chat_view.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/player_bar.dart';
import 'game_result_sheet.dart';
import 'game_screen.dart';
import 'review_screen.dart';
import 'setup_screen.dart';

/// [gameId]를 관전 화면으로 연다. 로그인하지 않아도 된다(`docs/screens.md`의 로그인).
/// 내가 두고 있는 대국이면 관전 대신 그 대국으로 간다.
Future<void> openSpectate(BuildContext context, String gameId) async {
  if (managers.playerStateManager.gameId == gameId) {
    await Navigator.of(context).push(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
    return;
  }
  await Navigator.of(context).push(createGameRoute<void>((context) => SpectateScreen(gameId: gameId)));
}

/// 관전 화면. 대국 화면의 관전 모드다(`docs/screens.md`의 대국 화면).
///
/// 초가 아래이고 판을 돌릴 수 있다. 남의 대국이므로 어느 쪽 기물도 어둡게 하지 않고, 차례는 시계와 정보 줄로만 보여준다.
/// 위에 "관전 · N명 보는 중"을 둔다. 관전 채팅은 넓은 화면이면 오른쪽 패널에 늘 펼쳐 두고, 아니면 버튼으로 아래에서 올린다.
/// 로그인하지 않은 관전자에게는 채팅 대신 로그인 안내를 보여준다.
class SpectateScreen extends StatefulWidget {
  final String gameId;

  const SpectateScreen({super.key, required this.gameId});

  @override
  State<SpectateScreen> createState() => _SpectateScreenState();
}

class _SpectateScreenState extends State<SpectateScreen> {
  late final OnlineGameManager _online;
  late final SpectateManager _spectate;
  late final ChatManager _chat;
  var _resultShown = false;

  @override
  void initState() {
    super.initState();
    _online = OnlineGameManager(
      gameId: widget.gameId,
      uid: managers.authManager.uid,
      connectionManager: managers.connectionManager,
    )..addListener(_onGameChanged);
    _spectate = SpectateManager(gameId: widget.gameId);
    _chat = ChatManager(
      channel: ChatChannel.spectator,
      gameId: widget.gameId,
      authManager: managers.authManager,
      blockManager: managers.blockManager,
    );
  }

  @override
  void dispose() {
    _online.removeListener(_onGameChanged);
    _online.dispose();
    _spectate.dispose();
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      body: ListenableBuilder(listenable: Listenable.merge([_online, _spectate]), builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final board = _online.board;
    final title = _getTitle(l10n);
    if (_online.loadError != null) {
      // 대국을 불러오지 못했어요
      return _buildMessage(context, title, l10n.errorGameLoad);
    }
    if (!_online.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final game = _online.game;
    if (game == null) {
      // 이미 끝난 대국이에요
      return _buildMessage(context, title, l10n.spectateGameGone);
    }
    if (board == null) {
      // 대국자가 상차림을 고르고 있어요
      return _buildMessage(context, title, l10n.spectateSetup);
    }
    final bottomSide = board.flipped ? Side.han : Side.cho;
    if (getLayoutSize(context) == LayoutSize.expanded) {
      return GameWideLayout(
        onBack: _onLeave,
        boardColumn: Column(
          children: [
            _buildPlayerBar(context, board, bottomSide.opponent),
            Flexible(child: _buildBoard(board)),
            _buildPlayerBar(context, board, bottomSide),
          ],
        ),
        panel: GamePanel(
          title: title,
          details: getGameDetails(l10n, game.meta),
          body: ChatView(chats: [_chat], style: ChatStyle.dark),
          buttons: _buildButtonBar(context, board, wide: true),
        ),
      );
    }
    return Column(
      children: [
        GameHeader(title: title, onBack: _onLeave),
        _buildPlayerBar(context, board, bottomSide.opponent),
        Expanded(
          child: Column(
            children: [
              Flexible(child: _buildBoard(board)),
              _buildPlayerBar(context, board, bottomSide),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: _buildButtonBar(context, board, wide: false)),
      ],
    );
  }

  /// "관전 · N명 보는 중". 관전 목록에 없는 대국(비공개 방 등)은 셀 수가 없어 "관전"만 쓴다. 대국 서버는 수를 받을 때 세므로
  /// 방금 들어온 나를 아직 세지 않았을 수 있어 1명보다 적게 보여주지 않는다.
  String _getTitle(AppLocalizations l10n) {
    final count = _spectate.spectatorCount;
    if (count == null) {
      // 관전
      return l10n.menuSpectate;
    }
    // 관전 · 12명 보는 중
    return l10n.spectateTitle(max(count, 1));
  }

  Widget _buildBoard(BoardManager board) {
    return BoardView(position: board.position, flipped: board.flipped, lastMove: board.lastMove);
  }

  Widget _buildMessage(BuildContext context, String title, String message) {
    return Column(
      children: [
        GameHeader(title: title, onBack: _onLeave),
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
    final game = _online.game!;
    return PlayerBar(
      side: side,
      active: !board.isOver && board.turn == side,
      name: getPlayerName(l10n, game.meta.players.get(side)),
      // 72점
      detail: l10n.score(formatScore(board.position.score(side))),
      notice: DisconnectNotice(online: _online, side: side),
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
        PlayerClock(online: _online, side: side),
      ],
    );
  }

  /// 관전 채팅, 판 돌리기, 나가기. 넓은 화면은 관전 채팅이 패널 가운데에 있어 버튼에서 뺀다.
  Widget _buildButtonBar(BuildContext context, BoardManager board, {required bool wide}) {
    final l10n = AppLocalizations.of(context);
    return GameButtonBar(
      children: [
        if (!wide)
          ChatBarButton(
            chats: [_chat],
            // 관전 채팅
            label: l10n.spectateChat,
          ),
        GameBarButton(
          icon: Icons.sync,
          // 판 돌리기
          label: l10n.flipBoard,
          onPressed: board.toggleFlipped,
        ),
        GameBarButton(
          icon: Icons.logout,
          // 나가기
          label: l10n.leaveGameAction,
          onPressed: _onLeave,
        ),
      ],
    );
  }

  void _onGameChanged() {
    final board = _online.board;
    if (board == null || !board.isOver || _resultShown) {
      return;
    }
    _resultShown = true;
    _showResult(board);
  }

  /// 관전자에게는 이긴 쪽 기준으로 보여준다(`docs/screens.md`의 대국 결과).
  Future<void> _showResult(BoardManager board) async {
    final action = await showGameSheet<GameResultAction>(
      context,
      builder: (context) => GameResultSheet(
        result: board.result!,
        moveCount: board.moveCount,
        elapsed: _online.getElapsed(),
        online: _online,
        spectating: true,
        chats: [_chat],
      ),
    );
    if (!mounted) {
      return;
    }
    switch (action) {
      case GameResultAction.review:
        final record = board.game;
        Navigator.of(context).pushReplacement(createGameRoute<void>((context) => ReviewScreen(record: record)));
      case GameResultAction.home:
        Navigator.of(context).pop();
      case GameResultAction.playAgain:
      case GameResultAction.rematch:
      case null:
        // 창만 닫으면 끝난 판을 그대로 본다.
        break;
    }
  }

  void _onLeave() {
    Navigator.of(context).maybePop();
  }
}
