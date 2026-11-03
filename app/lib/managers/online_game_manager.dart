import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:janggi_core/janggi_core.dart';

import '../config.dart';
import '../models/active_game.dart';
import '../models/connection.dart';
import '../models/game_enums.dart';
import '../repositories/app_repositories.dart';
import '../utils/game_clock.dart';
import 'board_manager.dart';
import 'connection_manager.dart';

/// 온라인 대국 하나의 상태. 상차림 화면, 대국 화면, 관전 화면이 각자 만들고 `dispose()`한다.
///
/// 관전 화면에서는 내 진영([mySide])이 없으므로 판을 서버 상태에 맞추기만 하고 `checkGame`을 부르지 않는다.
///
/// RTDB `games_active/{gameId}`를 듣고 상차림과 판을 서버 상태에 맞춘다. 대국 상태는 서버만 쓰므로 앱은 API를 부르고
/// 바뀐 값을 다시 받아 그린다. 내 수는 서버에 보내자마자 판에 먼저 보여주고, 서버가 거절하면 서버 상태로 되돌린다.
///
/// 접속 끊김은 서버가 판정하므로(`docs/server.md`의 접속 끊김) 앱은 판정을 다시 볼 계기만 준다. 상대의 `connections`가
/// 서버 기록과 다르거나(끊겼는데 기록이 없거나, 돌아왔는데 기록이 남아 있다), 서버가 나를 끊긴 것으로 기록했는데 나는
/// 연결되어 있거나, 상대 시계가 0이 되면 `checkGame`을 부른다.
class OnlineGameManager extends ChangeNotifier {
  /// 상차림 시간 안에 아무것도 누르지 않았을 때의 상차림(`docs/game/time.md`).
  static const defaultFormation = Formation.horseElephantHorseElephant;

  /// 각 진영 뒷줄에서 마·상이 놓이는 세로줄. 어느 진영이든 b, c, g, h 세로줄이다.
  static const _formationFiles = [1, 2, 6, 7];

  final String gameId;

  /// 이 기기에 로그인한 사용자. 로그인하지 않은 관전자면 null이다.
  final String? uid;

  /// 내 접속 상태. 서버가 나를 끊긴 것으로 기록했을 때 연결되어 있는지 본다.
  final ConnectionManager connectionManager;

  /// 서버 시각(ms)을 [gameClockTickInterval]마다 알린다. 시계와 상차림 남은 시간만 이 값을 듣고 다시 그린다.
  final ValueNotifier<int> serverNow;

  StreamSubscription<ActiveGame?>? _gameSubscription;
  StreamSubscription<Duration>? _offsetSubscription;
  StreamSubscription<List<Connection>>? _opponentSubscription;
  Timer? _ticker;

  ActiveGame? _game;
  bool _removed = false;
  bool _loaded = false;
  Object? _loadError;
  Duration _serverTimeOffset = Duration.zero;

  // 상차림 화면에서 골라 둔 상차림. 확정하면 서버 값을 따른다.
  Formation _picked = defaultFormation;
  bool _formationSending = false;

  BoardManager? _board;

  // 서버에 보내고 답을 기다리는 내 수의 번호. 그동안 온 서버 상태에 그 수가 없어도 판을 되돌리지 않는다.
  int? _pendingMoveIndex;

  // 상대의 연결 중 `online`이고 `foreground`인 것이 있는지. 처음 값을 받기 전에는 null이다.
  bool? _opponentOnline;

  // 마지막으로 `checkGame`을 부른 까닭과 그때의 대국 `version`. 서버 상태가 그대로인 동안 같은 까닭으로 다시 부르지 않는다.
  String? _checkedReason;

  // 상대 시계가 0이 되어 `checkGame`을 부른 차례의 시작 시각.
  int? _timeoutCheckedTurnStartedAt;

  OnlineGameManager({required this.gameId, required this.uid, required this.connectionManager})
    : serverNow = ValueNotifier(DateTime.now().millisecondsSinceEpoch) {
    _gameSubscription = repositories.gameRepository.watchGame(gameId).listen(_onGameChanged, onError: _onGameError);
    _offsetSubscription = repositories.serverTimeRepository.watchServerTimeOffset().listen(
      _onServerTimeOffsetChanged,
      onError: _onServerTimeOffsetError,
    );
    _ticker = Timer.periodic(gameClockTickInterval, _onTick);
    connectionManager.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _offsetSubscription?.cancel();
    _opponentSubscription?.cancel();
    _ticker?.cancel();
    connectionManager.removeListener(_onConnectionChanged);
    _board?.removeListener(_onBoardChanged);
    _board?.dispose();
    serverNow.dispose();
    super.dispose();
  }

  /// 대국. 처음 값을 받기 전이거나 대국이 지워졌으면 null이다. 끝난 뒤에 지워졌으면 끝났을 때의 상태다([removed]).
  ActiveGame? get game => _game;

  /// 끝난 대국을 서버가 RTDB에서 지웠다. 재대국을 할 수 없다.
  bool get removed => _removed;

  /// 처음 값을 받았는지 여부.
  bool get loaded => _loaded;

  /// 대국을 듣지 못한 오류. 화면이 알린다.
  Object? get loadError => _loadError;

  GamePhase? get phase => _game?.state.phase;

  /// 내 진영. 대국자가 아니면 null이다.
  Side? get mySide {
    final players = _game?.meta.players;
    if (players == null) {
      return null;
    }
    if (players.cho.uid == uid) {
      return Side.cho;
    }
    if (players.han.uid == uid) {
      return Side.han;
    }
    return null;
  }

  /// 대국 판. 상차림이 끝나 처음 국면이 생긴 뒤에 있다.
  BoardManager? get board => _board;

  /// 대국이 끝난 뒤 상대가 대국 화면을 나갔는지 여부(`docs/screens.md`의 대국 결과). 상대가 나가기를 눌러 서버가 재대국을
  /// 취소했거나, 상대 앱이 꺼졌거나 뒤로 갔으면 true다. 대국 중이거나 대국자가 아니면 false다.
  bool get opponentLeft {
    final game = _game;
    if (game == null || mySide == null || game.state.phase != GamePhase.finished) {
      return false;
    }
    final rematch = game.rematch;
    if (rematch?.cancelled == true && rematch?.gameId == null) {
      return true;
    }
    return _opponentOnline == false;
  }

  /// 서버 시각 어림값(ms).
  int getServerNowMs() => DateTime.now().add(_serverTimeOffset).millisecondsSinceEpoch;

  // ---- 상차림 ----

  /// 내가 골라 둔 상차림. 확정했으면 확정한 것이다.
  Formation get picked {
    final side = mySide;
    final confirmed = side == null ? null : _game?.state.setup.get(side);
    return confirmed ?? _picked;
  }

  /// 지금 내가 상차림을 고를 수 있는지 여부.
  bool get canPickFormation {
    final game = _game;
    final side = mySide;
    if (game == null || side == null || _formationSending) {
      return false;
    }
    final setup = game.state.setup;
    return game.state.phase == GamePhase.setup && setup.turn == side && setup.get(side) == null;
  }

  /// [side]가 상차림을 확정했는지 여부.
  bool hasConfirmedFormation(Side side) => _game?.state.setup.get(side) != null;

  /// 지금 상차림을 고르는 진영. 상차림 중이 아니면 null이다.
  Side? get setupTurn {
    final game = _game;
    if (game == null || game.state.phase != GamePhase.setup) {
      return null;
    }
    return game.state.setup.turn;
  }

  /// 상차림 화면의 판. 확정한 쪽은 확정한 것, 나는 골라 둔 것, 상대가 아직 고르지 않았으면 기본 상차림으로 놓는다.
  Position get setupPreview {
    final setup = _game?.state.setup;
    final side = mySide;
    return createInitialPosition(
      cho: setup?.cho ?? (side == Side.cho ? _picked : defaultFormation),
      han: setup?.han ?? (side == Side.han ? _picked : defaultFormation),
      hanRemoved: {...?_game?.meta.handicap},
    );
  }

  /// [side]의 마·상 네 자리.
  Set<Square> getFormationSquares(Side side) {
    final rank = side == Side.cho ? 0 : Square.rankCount - 1;
    return {for (final file in _formationFiles) Square(file, rank)};
  }

  /// 상차림을 골라 둔다. 마감이 지나면 서버가 골라 둔 것으로 확정하므로 서버에도 알린다.
  Future<void> pickFormation(Formation formation) async {
    if (!canPickFormation) {
      return;
    }
    _picked = formation;
    notifyListeners();
    await repositories.gameRepository.setFormation(gameId, formation, confirmed: false);
  }

  /// 골라 둔 상차림으로 확정한다.
  Future<void> confirmFormation() async {
    if (!canPickFormation) {
      return;
    }
    try {
      _formationSending = true;
      notifyListeners();
      await repositories.gameRepository.setFormation(gameId, _picked, confirmed: true);
    } finally {
      _formationSending = false;
      notifyListeners();
    }
  }

  // ---- 대국 ----

  /// 판의 교차점을 눌렀을 때. 수가 되면 서버에 보낸다. 서버가 거절하면 서버 상태로 되돌리고 오류를 던진다.
  Future<void> tapSquare(Square square) async {
    final board = _board;
    if (board == null) {
      return;
    }
    final moveCount = board.moveCount;
    board.tapSquare(square);
    if (board.moveCount == moveCount) {
      return;
    }
    await _sendLastMove(board);
  }

  /// 한수쉼을 서버에 보낸다.
  Future<void> pass() async {
    final board = _board;
    if (board == null) {
      return;
    }
    board.pass();
    await _sendLastMove(board);
  }

  Future<void> resign() async {
    await repositories.gameRepository.resign(gameId);
  }

  /// 대국에 걸린 시간. 상차림 시작부터 끝날 때(끝나지 않았으면 지금)까지다.
  Duration getElapsed() {
    final game = _game;
    if (game == null) {
      return Duration.zero;
    }
    final endedAt = game.state.endedAt ?? getServerNowMs();
    return Duration(milliseconds: endedAt - game.state.setup.startsAt);
  }

  Future<void> _sendLastMove(BoardManager board) async {
    final moveIndex = board.moveCount - 1;
    final move = board.lastMove!;
    _pendingMoveIndex = moveIndex;
    try {
      await repositories.gameRepository.playMove(gameId, moveIndex: moveIndex, move: move);
    } catch (_) {
      _pendingMoveIndex = null;
      _syncBoard();
      rethrow;
    }
    if (_pendingMoveIndex == moveIndex) {
      _pendingMoveIndex = null;
    }
  }

  void _onGameChanged(ActiveGame? game) {
    // 끝난 대국은 정리 작업이 RTDB에서 지운 뒤에도 같은 화면에서 복기를 이어 가도록 마지막 상태를 남긴다.
    if (game == null && _game?.state.phase == GamePhase.finished) {
      _removed = true;
      notifyListeners();
      return;
    }
    _game = game;
    _loaded = true;
    _loadError = null;
    _syncBoard();
    _watchOpponent();
    notifyListeners();
    _checkGameIfNeeded();
  }

  /// 대국자를 알게 되면 상대의 연결을 듣기 시작한다.
  void _watchOpponent() {
    final side = mySide;
    if (_opponentSubscription != null || side == null) {
      return;
    }
    final opponentUid = _game!.meta.players.get(side.opponent).uid;
    _opponentSubscription = repositories.connectionRepository
        .watchConnections(opponentUid)
        .listen(_onOpponentConnectionsChanged, onError: _onOpponentConnectionsError);
  }

  void _onOpponentConnectionsChanged(List<Connection> connections) {
    final online = connections.any((connection) => connection.online && connection.foreground);
    if (online == _opponentOnline) {
      return;
    }
    _opponentOnline = online;
    // 상대가 끊겼다 돌아오기를 반복하면 서버 상태가 같아도 다시 알린다.
    _checkedReason = null;
    _checkGameIfNeeded();
    // 대국이 끝난 뒤에는 상대가 화면을 나갔는지([opponentLeft])가 바뀐다.
    if (_game?.state.phase == GamePhase.finished) {
      notifyListeners();
    }
  }

  void _onOpponentConnectionsError(Object error, StackTrace stackTrace) {
    developer.log('OnlineGameManager 상대 연결 듣기 실패', error: error, stackTrace: stackTrace);
  }

  void _onConnectionChanged() {
    _checkGameIfNeeded();
  }

  /// 서버의 접속 끊김 기록이 앱이 본 것과 다르면 판정을 다시 보게 한다.
  void _checkGameIfNeeded() {
    final game = _game;
    final side = mySide;
    if (game == null || side == null || game.state.phase == GamePhase.finished) {
      return;
    }
    final disconnect = game.state.disconnect;
    final opponentSince = disconnect.get(side.opponent).since;
    final String reason;
    if (disconnect.get(side).since != null && connectionManager.active) {
      reason = 'returned';
    } else if (_opponentOnline == false && opponentSince == null) {
      reason = 'opponentLeft';
    } else if (_opponentOnline == true && opponentSince != null) {
      reason = 'opponentReturned';
    } else {
      return;
    }
    final checkedReason = '$reason:${game.state.version}';
    if (checkedReason == _checkedReason) {
      return;
    }
    _checkedReason = checkedReason;
    _requestCheck(renewActiveSince: reason == 'returned');
  }

  /// 상대 시계가 0이 되면 판정을 다시 보게 한다. 차례마다 한 번만 부른다.
  void _checkTimeoutIfNeeded(int nowMs) {
    final game = _game;
    final side = mySide;
    if (game == null || side == null || game.state.turn != side.opponent) {
      return;
    }
    final timeoutAt = getTimeoutAt(game);
    final turnStartedAt = game.state.turnStartedAt;
    if (timeoutAt == null || nowMs < timeoutAt || turnStartedAt == _timeoutCheckedTurnStartedAt) {
      return;
    }
    _timeoutCheckedTurnStartedAt = turnStartedAt;
    _requestCheck(renewActiveSince: false);
  }

  /// `checkGame`을 부른다. [renewActiveSince]면 서버가 돌아온 것으로 셀 수 있게 먼저 `activeSince`를 새로 쓴다.
  /// 실패해도 상대 앱이나 예약 작업이 다시 판정하므로 로그만 남긴다.
  Future<void> _requestCheck({required bool renewActiveSince}) async {
    try {
      if (renewActiveSince) {
        await connectionManager.renewActiveSince();
      }
      await repositories.gameRepository.checkGame(gameId);
    } catch (error, stackTrace) {
      developer.log('OnlineGameManager checkGame 실패', error: error, stackTrace: stackTrace);
    }
  }

  void _onGameError(Object error, StackTrace stackTrace) {
    _loadError = error;
    notifyListeners();
  }

  void _onServerTimeOffsetChanged(Duration offset) {
    _serverTimeOffset = offset;
  }

  void _onServerTimeOffsetError(Object error, StackTrace stackTrace) {
    developer.log('OnlineGameManager 서버 시각 듣기 실패', error: error, stackTrace: stackTrace);
  }

  void _onTick(Timer timer) {
    final nowMs = getServerNowMs();
    serverNow.value = nowMs;
    _checkTimeoutIfNeeded(nowMs);
  }

  void _onBoardChanged() {
    notifyListeners();
  }

  /// 판을 서버 상태에 맞춘다. 처음 국면이 생기면(상차림 중에 끝났으면 그때) 판을 만들고, 내가 보낸 수를 기다리는 동안은
  /// 되돌리지 않는다.
  void _syncBoard() {
    final game = _game;
    if (game == null || (game.state.initialFen == null && game.state.phase != GamePhase.finished)) {
      return;
    }
    final board = _board;
    if (board == null) {
      final side = mySide;
      final created = BoardManager.fromGame(_buildGame(game, null), flipped: side == Side.han, player: side);
      created.addListener(_onBoardChanged);
      _board = created;
      return;
    }
    final pendingMoveIndex = _pendingMoveIndex;
    if (pendingMoveIndex != null && game.moves.length == pendingMoveIndex && game.state.phase != GamePhase.finished) {
      return;
    }
    final next = _buildGame(game, board.game);
    if (next.moves.length == board.game.moves.length && next.result == board.game.result) {
      return;
    }
    board.syncGame(next);
  }

  /// 서버 상태의 대국. [current]가 서버 수의 앞부분이면 이어서 두고, 아니면 처음부터 다시 둔다.
  /// 시간패와 기권처럼 수 밖에서 끝난 결과도 붙인다.
  static Game _buildGame(ActiveGame game, Game? current) {
    final moves = [for (final record in game.moves) Move.parse(record.m)];
    var played = Game.start(_getInitialPosition(game));
    if (current != null && current.moves.length <= moves.length && !current.isOver && _isPrefix(current.moves, moves)) {
      played = current;
    }
    for (final move in moves.skip(played.moves.length)) {
      played = played.play(move);
    }
    final result = game.state.result;
    if (result == null || played.isOver) {
      return played;
    }
    final loser = result.winner.opponent;
    return switch (result.reason) {
      GameEndReason.timeout => played.timeout(loser),
      GameEndReason.disconnect => played.disconnect(loser),
      _ => played.resign(loser),
    };
  }

  /// 처음 국면. 상차림 중에 끝난 대국은 확정한 것과 기본 상차림으로 만든다. 서버의 기보 저장과 같다.
  static Position _getInitialPosition(ActiveGame game) {
    final initialFen = game.state.initialFen;
    if (initialFen != null) {
      return Position.fromFen(initialFen);
    }
    final setup = game.state.setup;
    return createInitialPosition(
      cho: setup.cho ?? defaultFormation,
      han: setup.han ?? defaultFormation,
      hanRemoved: {...?game.meta.handicap},
    );
  }

  static bool _isPrefix(List<Move> prefix, List<Move> moves) {
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] != moves[i]) {
        return false;
      }
    }
    return true;
  }
}
