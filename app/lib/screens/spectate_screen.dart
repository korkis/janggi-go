import 'dart:math';

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/board_manager.dart';
import '../managers/chat_manager.dart';
import '../managers/online_game_manager.dart';
import '../managers/review_manager.dart';
import '../managers/spectate_manager.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import '../utils/game_format.dart';
import '../utils/rank_format.dart';
import '../utils/score_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/board/board_view.dart';
import '../widgets/board/check_effect.dart';
import '../widgets/chat_view.dart';
import '../widgets/game_result.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/player_bar.dart';
import 'game_screen.dart';
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
/// 초가 아래다. 남의 대국이므로 어느 쪽 기물도 어둡게 하지 않고, 차례는 시계와 정보 줄로만 보여준다.
/// 위에 "관전 · N명 보는 중"을 둔다. 관전 채팅은 넓은 화면이면 오른쪽 패널에 늘 펼쳐 두고, 아니면 아래 미리보기 한 줄을 눌러
/// 올린다. 로그인하지 않은 관전자에게는 채팅 대신 로그인 안내를 보여준다.
///
/// 대국이 끝나면 대국 화면처럼 같은 화면이 복기 모드로 바뀌고, 이긴 쪽 기준의 결과 도장을 찍는다.
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

  // 대국이 끝난 뒤의 복기. 대국 중에는 null이다.
  ReviewManager? _review;

  // 결과 도장이 머리줄 결과 칩에 닿았다.
  var _resultLanded = false;
  final _resultChipKey = GlobalKey();

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
    _review?.removeListener(_onReviewChanged);
    _review?.dispose();
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
    final review = _review;
    final bottomSide = board.flipped ? Side.han : Side.cho;
    final resultChip = review == null ? null : _buildResultChip(context, board);
    if (getLayoutSize(context) == LayoutSize.expanded) {
      return GameWideLayout(
        onBack: _onLeave,
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
          details: getGameDetails(l10n, game.meta),
          body: ChatView(chats: [_chat], style: ChatStyle.dark),
          buttons: _buildButtons(context, review),
        ),
      );
    }
    return Column(
      children: [
        GameHeader(title: title, onBack: _onLeave, chip: resultChip),
        _buildPlayerBar(context, board, bottomSide.opponent),
        Expanded(
          child: Column(
            children: [
              Flexible(child: _buildBoard(context, board)),
              _buildPlayerBar(context, board, bottomSide),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ChatPreviewLine(chats: [_chat]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: _buildButtons(context, review)),
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

  Widget _buildBoard(BuildContext context, BoardManager board) {
    final review = _review;
    if (review != null) {
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          BoardView(position: review.position, flipped: board.flipped, lastMove: review.lastMove),
          if (!_resultLanded)
            Positioned.fill(
              child: ResultStampOverlay(
                won: true,
                detail: getResultDetail(
                  AppLocalizations.of(context),
                  board.result!,
                  null,
                  board.moveCount,
                  _online.getElapsed(),
                ),
                targetKey: _resultChipKey,
                onLanded: _onResultLanded,
              ),
            ),
        ],
      );
    }
    final disconnectedSide = _getDisconnectedSide();
    return Stack(
      alignment: Alignment.center,
      children: [
        BoardView(
          position: board.position,
          flipped: board.flipped,
          lastMove: board.lastMove,
          checkedSide: board.checkedSide,
          firstCheck: board.isFirstCheck,
        ),
        if (disconnectedSide != null)
          Positioned.fill(
            child: DisconnectCard(online: _online, side: disconnectedSide),
          ),
      ],
    );
  }

  /// 서버가 끊긴 것으로 기록한 대국자. 둘 다 끊겼으면 먼저 끊긴 쪽이다.
  Side? _getDisconnectedSide() {
    final disconnect = _online.game?.state.disconnect;
    final cho = disconnect?.get(Side.cho).since;
    final han = disconnect?.get(Side.han).since;
    if (cho != null && (han == null || cho <= han)) {
      return Side.cho;
    }
    return han != null ? Side.han : null;
  }

  /// 머리줄(넓은 화면은 패널)의 결과 칩 "초 승리 · 외통승". 결과 도장이 닿기 전에는 자리만 잡아 둔다.
  Widget _buildResultChip(BuildContext context, BoardManager board) {
    return AnimatedOpacity(
      key: _resultChipKey,
      opacity: _resultLanded ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: ResultChip(text: getResultHeadline(AppLocalizations.of(context), board.result!, null), won: true),
    );
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
    final review = _review;
    final checked = review == null && board.checkedSide == side;
    return PlayerBar(
      side: side,
      active: review == null && board.turn == side,
      checked: checked,
      name: getPlayerName(l10n, game.meta.players.get(side)),
      // 72점
      detail: l10n.score(formatScore((review?.position ?? board.position).score(side))),
      trailing: [
        if (checked)
          PlayerBadge(
            // 장군
            label: l10n.check,
            color: CheckColors.paper,
            background: CheckColors.stamp,
          ),
        if (review == null && board.hasPassedLast(side))
          PlayerBadge(
            // 한수쉼
            label: l10n.passedLast,
            color: GameColors.subText,
          ),
        if (review == null) PlayerClock(online: _online, side: side),
      ],
    );
  }

  /// 나가기. 대국이 끝났으면 위에 복기 막대를 둔다.
  Widget _buildButtons(BuildContext context, ReviewManager? review) {
    final l10n = AppLocalizations.of(context);
    final buttonBar = GameButtonBar(
      children: [
        GameBarButton(
          icon: Icons.logout,
          // 나가기
          label: l10n.leaveGameAction,
          onPressed: _onLeave,
        ),
      ],
    );
    if (review == null) {
      return buttonBar;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReviewBar(review: review),
        const SizedBox(height: 8),
        buttonBar,
      ],
    );
  }

  void _onGameChanged() {
    final board = _online.board;
    if (board == null || !board.isOver || _review != null) {
      return;
    }
    // 끝난 판을 같은 화면에서 마지막 수부터 복기한다.
    _review = ReviewManager(record: board.game)..addListener(_onReviewChanged);
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

  void _onLeave() {
    Navigator.of(context).maybePop();
  }
}
