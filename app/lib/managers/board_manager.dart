import 'package:flutter/foundation.dart';
import 'package:janggi_core/janggi_core.dart';

/// 한 대국의 판 상태. 대국 화면이 만들고 `dispose()`한다.
///
/// 한 기기에서 양쪽을 두는 개발용 대국과, 한 진영([player])만 두는 온라인 대국에 쓴다. 온라인 대국은 수를 먼저 판에 보여주고
/// 서버 상태가 오면 [syncGame]으로 맞춘다. 규칙 판정은 모두 `janggi_core`가 한다.
class BoardManager extends ChangeNotifier {
  Game _game;

  /// 지금 차례가 둘 수 있는 수. 국면이 바뀔 때마다 한 번만 구한다.
  List<Move> _legalMoves;
  Square? _selected;
  Set<Square> _targets = const {};
  bool _flipped;

  /// 이 기기가 두는 진영. null이면 한 기기에서 양쪽을 둔다.
  final Side? player;
  final DateTime _startedAt;
  DateTime? _endedAt;

  BoardManager({required Position initialPosition, bool flipped = false, DateTime? startedAt})
    : this.fromGame(Game.start(initialPosition), flipped: flipped, startedAt: startedAt);

  /// 이미 수를 둔 [game]에서 이어서 둔다. 복기의 놓아보기처럼 지나온 수(반복수 판정)가 필요할 때 쓴다.
  BoardManager.fromGame(this._game, {this._flipped = false, this.player, DateTime? startedAt})
    : _legalMoves = const [],
      _startedAt = startedAt ?? DateTime.now() {
    _legalMoves = _game.legalMoves();
    if (_game.isOver) {
      _endedAt = _startedAt;
    }
  }

  Game get game => _game;

  Position get position => _game.position;

  Side get turn => _game.position.turn;

  GameResult? get result => _game.result;

  bool get isOver => _game.isOver;

  /// 고른 기물의 칸. 고른 기물이 없으면 null이다.
  Square? get selected => _selected;

  /// 고른 기물이 갈 수 있는 자리.
  Set<Square> get targets => _targets;

  /// true면 한이 아래에 오도록 판을 돌려 보여준다.
  bool get flipped => _flipped;

  /// 마지막으로 둔 수. 아직 둔 수가 없으면 null이다.
  Move? get lastMove => _game.moves.isEmpty ? null : _game.moves.last;

  int get moveCount => _game.moves.length;

  /// 장군을 받은 진영. 장군을 받을 수 있는 쪽은 차례인 쪽뿐이다.
  Side? get checkedSide => !isOver && position.isInCheck(turn) ? turn : null;

  bool get canPass => isPlayerTurn && _legalMoves.contains(Move.pass);

  /// 이 기기가 둘 차례인지 여부. 한 기기에서 양쪽을 두면 끝나기 전까지 늘 true다.
  bool get isPlayerTurn => !isOver && (player == null || player == turn);

  /// 차례가 아니어서 기물을 살짝 어둡게 보여줄 진영. 대국이 끝나면 null이다.
  Side? get dimmedSide => isOver ? null : turn.opponent;

  /// [side]가 마지막으로 둔 수가 한수쉼인지 여부.
  bool hasPassedLast(Side side) {
    final moves = _game.moves;
    for (var i = moves.length - 1; i >= 0; i--) {
      if (_game.positions[i].turn == side) {
        return moves[i].isPass;
      }
    }
    return false;
  }

  /// 대국에 걸린 시간. 끝났으면 끝난 때까지다.
  Duration getElapsed(DateTime now) => (_endedAt ?? now).difference(_startedAt);

  /// 판의 교차점을 눌렀을 때. 차례인 쪽 기물이면 고르고, 고른 기물이 갈 수 있는 자리면 수를 둔다.
  void tapSquare(Square square) {
    if (!isPlayerTurn) {
      return;
    }
    final selected = _selected;
    if (selected != null && _targets.contains(square)) {
      _play(Move(selected, square));
      return;
    }
    final piece = position.pieceAt(square);
    if (piece != null && piece.side == turn && square != selected) {
      _select(square);
    } else {
      _select(null);
    }
    notifyListeners();
  }

  /// 한수쉼. 장군을 받은 상태 등 한수쉼을 할 수 없으면 [StateError]를 던진다.
  void pass() {
    if (!canPass) {
      throw StateError('한수쉼을 할 수 없는 국면이다 (${position.fen})');
    }
    _play(Move.pass);
  }

  /// 지금 차례인 쪽이 기권한다.
  void resign() {
    if (isOver) {
      throw StateError('이미 끝난 대국이다');
    }
    _game = _game.resign(turn);
    _onGameChanged();
  }

  /// 서버가 알려 준 [game]으로 판을 바꾼다. 국면이 그대로면 고른 기물을 남긴다.
  void syncGame(Game game) {
    final samePosition = game.position == _game.position && game.moves.length == _game.moves.length;
    _game = game;
    _legalMoves = _game.legalMoves();
    if (!samePosition || !isPlayerTurn) {
      _select(null);
    } else {
      _select(_selected);
    }
    if (_game.isOver) {
      _endedAt ??= DateTime.now();
    }
    notifyListeners();
  }

  void toggleFlipped() {
    _flipped = !_flipped;
    notifyListeners();
  }

  void _play(Move move) {
    _game = _game.play(move);
    _onGameChanged();
  }

  void _onGameChanged() {
    _legalMoves = _game.legalMoves();
    _select(null);
    if (_game.isOver) {
      _endedAt ??= DateTime.now();
    }
    notifyListeners();
  }

  void _select(Square? square) {
    _selected = square;
    if (square == null) {
      _targets = const {};
      return;
    }
    _targets = {
      for (final move in _legalMoves)
        if (move.from == square) move.to!,
    };
  }
}
