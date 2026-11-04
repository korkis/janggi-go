import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/board_manager.dart';
import '../managers/chat_manager.dart';
import '../managers/online_game_manager.dart';
import '../managers/review_manager.dart';
import '../models/chat_message.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/game_clock.dart';
import '../utils/game_format.dart';
import '../utils/game_sounds.dart';
import '../utils/rank_format.dart';
import '../utils/score_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/board/board_view.dart';
import '../widgets/chat_view.dart';
import '../widgets/game_result.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/player_bar.dart';
import 'room_screen.dart';
import 'setup_screen.dart';

/// 대국 화면. 개발용 대국과 온라인 대국이 같은 화면을 쓰고 모드에 따라 정보 줄과 버튼만 바꾼다(`docs/screens.md`의 대국 화면).
///
/// 개발용 대국([gameId]가 null)은 한 기기에서 양쪽을 두고 초가 아래에 온다. 온라인 대국은 내 진영이 아래이고 내 차례에만 두며,
/// 정보 줄에 닉네임, 급수, 시계를 보여준다. 어느 모드든 차례가 아닌 쪽의 기물을 살짝 어둡게 한다.
///
/// 대국이 끝나면 결과 창 없이 같은 화면이 복기 모드로 바뀐다(`docs/screens.md`의 대국 결과). 판 가운데에 결과 도장을 찍고
/// 머리줄 결과 칩으로 올려 보내며, 아래에는 채팅 미리보기, 복기 막대, 재대국 신청·나가기를 둔다.
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

  // 온라인 대국의 대국 채팅. 개발용 대국이면 null이다.
  ChatManager? _gameChat;

  // 대국이 끝난 뒤 대국자도 보는 관전 채팅(`docs/moderation.md`의 채팅 종류). 대국 중에는 null이다.
  ChatManager? _spectatorChat;

  // 대국이 끝난 뒤의 복기. 대국 중에는 null이다.
  ReviewManager? _review;

  // 결과 도장이 머리줄 결과 칩에 닿았다. 그 뒤로 결과 칩을 보여준다.
  var _resultLanded = false;

  // 결과 도장이 올라가 닿을 머리줄 결과 칩.
  final _resultChipKey = GlobalKey();

  // 재대국 신청을 보내는 중이다.
  var _rematchSending = false;

  // 화면을 나가기 시작했다(나가기, 재대국 대국으로 옮겨 가기). 서버 상태가 또 바뀌어도 다시 나가지 않는다.
  var _leaving = false;

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
      managers.playerStateManager.addListener(_onRematchChanged);
    }
  }

  @override
  void dispose() {
    _localBoard?.removeListener(_onBoardChanged);
    _localBoard?.dispose();
    _online?.removeListener(_onBoardChanged);
    _online?.dispose();
    if (_online != null) {
      managers.playerStateManager.removeListener(_onRematchChanged);
    }
    _gameChat?.dispose();
    _spectatorChat?.dispose();
    _review?.removeListener(_onReviewChanged);
    _review?.dispose();
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
    final review = _review;
    final bottomSide = board.flipped ? Side.han : Side.cho;
    final game = online?.game;
    // 온라인 대국 · 4수 / 개발용 대국 · 4수
    final title = online != null ? l10n.gameOnlineTitle(board.moveCount) : l10n.gameDevTitle(board.moveCount);
    final resultChip = review == null ? null : _buildResultChip(context, board);
    final chats = _chats;
    if (getLayoutSize(context) == LayoutSize.expanded) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: _onPopInvoked,
        child: GameWideLayout(
          onBack: _onBack,
          boardColumn: Column(
            children: [
              _buildPlayerBar(context, board, bottomSide.opponent),
              Flexible(child: _buildBoard(context, board)),
              _buildPlayerBar(context, board, bottomSide),
            ],
          ),
          panel: GamePanel(
            title: title,
            chip: resultChip,
            details: game == null ? const [] : getGameDetails(l10n, game.meta),
            body: chats.isEmpty ? null : ChatView(chats: chats, style: ChatStyle.dark),
            buttons: review == null
                ? _buildButtonBar(context, board, wide: true)
                : _buildResultActions(context, board, review),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Column(
        children: [
          GameHeader(title: title, onBack: _onBack, chip: resultChip),
          _buildPlayerBar(context, board, bottomSide.opponent),
          // 판과 아래 정보 줄을 붙여 두고 남는 높이는 버튼 줄 위에 둔다.
          Expanded(
            child: Column(
              children: [
                Flexible(child: _buildBoard(context, board)),
                _buildPlayerBar(context, board, bottomSide),
              ],
            ),
          ),
          if (chats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ChatPreviewLine(chats: chats),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: review == null
                ? _buildButtonBar(context, board, wide: false)
                : _buildResultActions(context, board, review),
          ),
        ],
      ),
    );
  }

  /// 판. 대국 중에는 장군 연출과 상대 연결 끊김 카드를, 끝난 뒤에는 복기 국면과 결과 도장을 판 위에 둔다.
  Widget _buildBoard(BuildContext context, BoardManager board) {
    final review = _review;
    final online = _online;
    final mySide = online?.mySide;
    if (review != null) {
      final result = board.result!;
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          BoardView(
            position: review.position,
            flipped: board.flipped,
            lastMove: review.lastMove,
            selected: review.selected,
            targets: review.targets,
            onSquareTap: review.trying ? review.tapSquare : null,
          ),
          if (!_resultLanded)
            Positioned.fill(
              child: ResultStampOverlay(
                won: isResultWon(result, mySide),
                detail: _getResultDetail(context, board),
                targetKey: _resultChipKey,
                onLanded: _onResultLanded,
              ),
            ),
        ],
      );
    }
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
          checkedSide: board.checkedSide,
          onSquareTap: _onSquareTap,
        ),
        if (online != null && mySide != null)
          Positioned.fill(
            child: DisconnectCard(online: online, side: mySide.opponent),
          ),
        if (online != null) const ReconnectingNotice(),
      ],
    );
  }

  Widget _buildMessage(BuildContext context, String message) {
    return Column(
      children: [
        GameHeader(title: '', onBack: _onLeaveWithoutResult),
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
    final review = _review;
    if (review != null) {
      return PlayerBar(
        side: side,
        active: false,
        name: game == null ? null : getPlayerName(l10n, game.meta.players.get(side)),
        // 72점
        detail: l10n.score(formatScore(review.position.score(side))),
        trailing: [if (online != null && side == online.mySide) ResultRankChange(gameId: online.gameId)],
      );
    }
    return PlayerBar(
      side: side,
      active: !board.isOver && board.turn == side,
      name: game == null ? null : getPlayerName(l10n, game.meta.players.get(side)),
      // 72점
      detail: l10n.score(formatScore(board.position.score(side))),
      trailing: [
        if (board.hasPassedLast(side))
          PlayerBadge(
            // 한수쉼
            label: l10n.passedLast,
            color: GameColors.subText,
          ),
        if (game != null) PlayerClock(online: online!, side: side),
      ],
    );
  }

  /// 머리줄(넓은 화면은 패널)의 결과 칩 "승리 · 외통승". 결과 도장이 닿기 전에는 자리만 잡아 둔다.
  Widget _buildResultChip(BuildContext context, BoardManager board) {
    final l10n = AppLocalizations.of(context);
    final result = board.result!;
    final mySide = _online?.mySide;
    return AnimatedOpacity(
      key: _resultChipKey,
      opacity: _resultLanded ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: ResultChip(text: getResultHeadline(l10n, result, mySide), won: isResultWon(result, mySide)),
    );
  }

  /// 결과 도장 아래 칩 "외통승 · 87수 · 12분 40초".
  String _getResultDetail(BuildContext context, BoardManager board) {
    final online = _online;
    final elapsed = online != null ? online.getElapsed() : board.getElapsed(DateTime.now());
    return getResultDetail(AppLocalizations.of(context), board.result!, online?.mySide, board.moveCount, elapsed);
  }

  /// 한수쉼, 더보기. 넓은 화면([wide])에서는 더보기 대신 기권을 바로 둔다.
  Widget _buildButtonBar(BuildContext context, BoardManager board, {required bool wide}) {
    final l10n = AppLocalizations.of(context);
    final playing = !board.isOver;
    return GameButtonBar(
      children: [
        GameBarButton(
          icon: Icons.pause,
          // 한수쉼
          label: l10n.pass,
          onPressed: playing && board.canPass ? _onPass : null,
        ),
        if (wide)
          GameBarButton(
            icon: Icons.flag_outlined,
            // 기권
            label: l10n.resign,
            onPressed: playing ? _confirmResign : null,
          )
        else
          GameBarButton(
            icon: Icons.more_horiz,
            // 더보기
            label: l10n.more,
            onPressed: playing ? _onMore : null,
          ),
      ],
    );
  }

  /// 대국이 끝난 뒤의 복기 막대와 재대국 신청·나가기.
  Widget _buildResultActions(BuildContext context, BoardManager board, ReviewManager review) {
    final l10n = AppLocalizations.of(context);
    final rematch = _getRematchState(board);
    final note = rematch.note;
    final inRoom = _online?.game?.meta.roomId != null;
    final rematchLabel = Text(rematch.label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReviewBar(review: review),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              note,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTextSizes.body,
                color: rematch.requested ? GameColors.accent : GameColors.subText,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: rematch.primary
                  ? FilledButton(onPressed: rematch.enabled ? _onRematch : null, child: rematchLabel)
                  : OutlinedButton(onPressed: rematch.enabled ? _onRematch : null, child: rematchLabel),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _onExit,
                // 방 대기실로 / 나가기
                child: Text(inRoom ? l10n.resultBackToRoom : l10n.leaveGameAction),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 재대국 신청 버튼의 글자, 눌림, 강조와 그 아래 안내(`docs/screens.md`의 대국 결과).
  ///
  /// 진 사람에게는 주 버튼(채움), 이긴 사람에게는 외곽선 버튼이다. 내가 눌렀으면 상대를 기다리고, 상대가 먼저 눌렀으면 수락
  /// 버튼으로 바꾼다. 상대가 나갔거나 빠른 대국의 횟수에 닿았으면 끈다. 개발용 대국은 같은 기기에서 바로 다시 둔다.
  ({String label, bool enabled, bool primary, String? note, bool requested}) _getRematchState(BoardManager board) {
    final l10n = AppLocalizations.of(context);
    final online = _online;
    final mySide = online?.mySide;
    if (online == null || mySide == null) {
      // 재대국 신청
      return (label: l10n.resultRematch, enabled: true, primary: true, note: null, requested: false);
    }
    final rematch = online.game?.rematch;
    final primary = board.result?.winner != mySide;
    final pressed = rematch?.get(mySide) == true;
    final opponentPressed = rematch?.get(mySide.opponent) == true;
    final blocked = rematch?.blocked == true;
    final cancelled = online.opponentLeft;
    final removed = online.removed;
    final enabled = !blocked && !cancelled && !removed && !pressed && !_rematchSending && rematch?.gameId == null;
    String? note;
    var label = l10n.resultRematch;
    var requested = false;
    if (removed) {
      // 지금은 재대국을 할 수 없어요
      note = l10n.errorRematchUnavailable;
    } else if (blocked) {
      // 같은 상대와는 더 둘 수 없어요
      note = l10n.resultRematchBlocked;
    } else if (cancelled) {
      // 상대가 나가서 재대국을 할 수 없어요
      note = l10n.resultRematchCancelled;
    } else if (pressed) {
      // 상대를 기다리는 중
      label = l10n.resultRematchWaiting;
    } else if (opponentPressed) {
      // 상대가 재대국을 원해요
      note = l10n.resultRematchRequested;
      // 재대국 수락
      label = l10n.resultRematchAccept;
      requested = true;
    }
    return (label: label, enabled: enabled, primary: primary || requested, note: note, requested: requested);
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
    if (online != null) {
      _updateOpponentLeft(online);
      _onRematchChanged();
    }
    if (_review != null) {
      return;
    }
    // 끝난 판을 같은 화면에서 마지막 수부터 복기한다.
    _review = ReviewManager(record: board.game)..addListener(_onReviewChanged);
    GameSounds.playResult();
  }

  /// 대국이 끝난 뒤 상대가 화면을 나갔으면 대국 채팅 입력을 막는다.
  void _updateOpponentLeft(OnlineGameManager online) {
    final mySide = online.mySide;
    final game = online.game;
    if (mySide == null || game == null) {
      return;
    }
    _gameChat?.setLeft(online.opponentLeft ? game.meta.players.get(mySide.opponent).nickname : null);
  }

  /// 복기 막대로 수를 옮기면 판과 정보 줄을 다시 그린다.
  void _onReviewChanged() {
    setState(() {});
  }

  void _onResultLanded() {
    if (!mounted) {
      return;
    }
    setState(() {
      _resultLanded = true;
    });
  }

  /// 재대국 대국이 정해지고 내가 그 대국에 묶이면 그 대국의 상차림으로 옮겨 간다.
  void _onRematchChanged() {
    final rematchGameId = _online?.game?.rematch?.gameId;
    if (_leaving || rematchGameId == null || managers.playerStateManager.gameId != rematchGameId) {
      return;
    }
    _leaving = true;
    Navigator.of(context)
        .pushReplacement(createGameRoute<void>((context) => SetupScreen.online(gameId: rematchGameId)));
  }

  Future<void> _onRematch() async {
    final online = _online;
    if (online == null) {
      // 개발용 대국은 같은 기기에서 바로 다시 둔다.
      _leaving = true;
      Navigator.of(context).pushReplacement(createGameRoute<void>((context) => const SetupScreen()));
      return;
    }
    try {
      setState(() {
        _rematchSending = true;
      });
      await repositories.gameRepository.requestRematch(online.gameId);
    } catch (error, stackTrace) {
      developer.log('GameRepository.requestRematch 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 재대국을 신청하지 못했어요. 잠시 후 다시 해 주세요
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

  /// 대국이 끝난 화면을 나간다. 온라인 대국은 기다리던 재대국을 취소하고, 방 대국이면 홈 대신 방 대기실로 돌아간다
  /// (`docs/game/matching.md`의 방 유지).
  void _onExit() {
    if (_leaving) {
      return;
    }
    _leaving = true;
    final online = _online;
    if (online == null) {
      Navigator.of(context).pop();
      return;
    }
    unawaited(_leaveResult(online.gameId));
    final roomId = online.game?.meta.roomId;
    if (roomId != null) {
      RoomScreen.returnTo(Navigator.of(context), roomId);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 대국이 끝난 화면을 나갔다고 대국 서버에 알린다. 실패해도 화면은 넘어가고, 상대의 재대국은 서버가 접속 상태로 취소한다.
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
      case _MenuAction.resign:
        await _confirmResign();
    }
  }

  /// 더보기 창. 기권을 둔다. 소리 끄기는 효과음이 생기면 넣는다.
  Widget _buildMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  void _onLeaveWithoutResult() {
    Navigator.of(context).pop();
  }

  /// 대국 중 뒤로 가기는 한 번 더 확인한 뒤 나간다. 온라인 대국은 나가도 대국이 계속된다고 알린다.
  /// 대국이 끝난 뒤의 뒤로 가기는 나가기와 같다.
  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }
    if (_board?.isOver == true) {
      _onExit();
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

/// [side]의 연결이 끊긴 동안 판 가운데에 띄우는 카드(`docs/screens.md`의 대국 화면). 판을 살짝 어둡게 깔고, 이번 대국에서
/// 남은 끊김 허용 시간을 줄어드는 원과 숫자로, 그 아래에 돌아오지 않으면 누가 이기는지를 보여준다. 서버가 끊긴 것으로 기록한
/// 동안만 보이고, 서버 시각이 바뀔 때마다 이것만 다시 그린다.
class DisconnectCard extends StatelessWidget {
  static const _ringSize = 64.0;

  final OnlineGameManager online;
  final Side side;

  const DisconnectCard({super.key, required this.online, required this.side});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(valueListenable: online.serverNow, builder: _buildCard);
  }

  Widget _buildCard(BuildContext context, int nowMs, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final game = online.game;
    final remaining = game == null ? null : getDisconnectRemaining(game, side, nowMs);
    if (game == null || remaining == null) {
      return const SizedBox.shrink();
    }
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    final limitMs = game.meta.disconnectLimitMs;
    final players = game.meta.players;
    return ColoredBox(
      color: GameColors.scrim.withValues(alpha: GameColors.scrim.a * 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(color: GameColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: _ringSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: limitMs <= 0 ? 0 : remaining.inMilliseconds / limitMs,
                      strokeWidth: 5,
                      color: GameColors.check,
                      backgroundColor: GameColors.raisedButton,
                    ),
                    Center(
                      child: Text(
                        '$seconds',
                        style: const TextStyle(
                          fontSize: AppTextSizes.large,
                          fontWeight: FontWeight.w800,
                          color: GameColors.text,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                // {nickname}님 연결이 끊겼어요
                l10n.disconnectCardTitle(players.get(side).nickname),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTextSizes.body,
                  fontWeight: FontWeight.w800,
                  color: GameColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                // 30초 안에 돌아오지 않으면 {winner}님의 승리로 끝나요
                l10n.disconnectCardBody(seconds, players.get(side.opponent).nickname),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
              ),
            ],
          ),
        ),
      ),
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

enum _MenuAction { resign }

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
