import 'package:flutter/foundation.dart';
import 'package:janggi_core/janggi_core.dart';

import 'board_manager.dart';

/// 복기 화면의 상태. 복기 화면이 만들고 `dispose()`한다.
///
/// 기보의 몇 수째를 보는지와 놓아보기 판을 가진다. 놓아보기를 켜면 지금 보는 국면에서 이어 두는
/// [BoardManager]를 만들고, 끝내면 그 판을 버리고 원래 기보 위치로 돌아간다.
///
/// 처음, 이전, 다음은 놓아보기 중이면 놓아 본 수를 오간다(`docs/screens.md`의 대국 결과). 뒤로 간 자리에서 다른 수를 두면
/// 그 뒤의 수는 새 수로 바뀌고 갈래는 남기지 않는다.
class ReviewManager extends ChangeNotifier {
  /// 복기하는 대국. 처음 국면과 둔 수가 들어 있다.
  final Game record;

  /// 지금 보는 국면까지 둔 수의 개수. 0이면 처음 국면이다.
  int _ply;

  /// 놓아보기 판. 놓아보기를 끈 상태면 null이다.
  BoardManager? _trial;

  /// 놓아보기를 시작한 자리에서 둔 수 전체. 뒤로 가도 남아 있어 다음으로 다시 갈 수 있다.
  List<Move> _trialMoves = const [];

  /// [trying]이면 놓아보기를 켠 채로 시작한다(새 판에서 놓아보기).
  ReviewManager({required this.record, bool trying = false}) : _ply = record.moves.length {
    if (trying) {
      startTrial();
    }
  }

  @override
  void dispose() {
    _disposeTrial();
    super.dispose();
  }

  int get ply => _ply;

  int get totalMoves => record.moves.length;

  /// 놓아보기를 켠 상태인지 여부.
  bool get trying => _trial != null;

  Position get position => _trial?.position ?? record.positions[_ply];

  /// 판에 표시할 마지막 수. 놓아보기 중이면 놓아보기 판의 마지막 수다.
  Move? get lastMove {
    final trial = _trial;
    if (trial != null) {
      return trial.lastMove;
    }
    return _ply == 0 ? null : record.moves[_ply - 1];
  }

  Square? get selected => _trial?.selected;

  Set<Square> get targets => _trial?.targets ?? const {};

  RejectedTap? get rejectedTap => _trial?.rejectedTap;

  /// 놓아보기를 시작한 자리에서 지금 보는 자리까지 둔 수의 개수.
  int get trialMoveCount => _trial == null ? 0 : _trial!.moveCount - _ply;

  /// 처음이나 이전으로 갈 수 있는지 여부. 놓아보기 중이면 놓아보기를 시작한 자리까지다.
  bool get canGoBack => trying ? trialMoveCount > 0 : _ply > 0;

  /// 다음이나 끝으로 갈 수 있는지 여부. 놓아보기 중이면 놓아 본 수의 끝까지다.
  bool get canGoForward => trying ? trialMoveCount < _trialMoves.length : _ply < totalMoves;

  /// [ply]수째 국면으로 간다. 범위를 벗어나면 처음이나 끝으로 맞춘다. 놓아보기 중에는 움직이지 않는다.
  void goTo(int ply) {
    if (trying) {
      return;
    }
    final clamped = ply.clamp(0, totalMoves);
    if (clamped == _ply) {
      return;
    }
    _ply = clamped;
    notifyListeners();
  }

  /// 처음으로 간다. 놓아보기 중이면 놓아보기를 시작한 자리로 가고, 놓아 본 수는 남는다.
  void goFirst() => trying ? _goTrialTo(0) : goTo(0);

  void goPrevious() => trying ? _goTrialTo(trialMoveCount - 1) : goTo(_ply - 1);

  void goNext() => trying ? _goTrialTo(trialMoveCount + 1) : goTo(_ply + 1);

  void goLast() => goTo(totalMoves);

  /// 지금 보는 국면에서 놓아보기를 시작한다. 이미 놓아보기 중이면 아무것도 하지 않는다.
  void startTrial() {
    if (trying) {
      return;
    }
    // 반복수 판정에 지나온 수가 필요하므로 처음부터 지금 위치까지 다시 둔 대국에서 이어 둔다.
    final trial = BoardManager.fromGame(Game.replay(record.initialPosition, record.moves.take(_ply)));
    trial.addListener(_onTrialChanged);
    _trial = trial;
    notifyListeners();
  }

  /// 놓아보기를 끝낸다. 놓아 본 수를 지우고 시작하기 전의 기보 위치로 돌아간다.
  void endTrial() {
    if (!trying) {
      return;
    }
    _disposeTrial();
    notifyListeners();
  }

  /// 놓아보기 중에 판의 교차점을 눌렀을 때. 놓아보기를 끈 상태면 아무것도 하지 않는다.
  void tapSquare(Square square) {
    _trial?.tapSquare(square);
  }

  /// 놓아 본 수 가운데 [count]수까지 둔 자리로 간다. 범위를 벗어나면 가지 않는다.
  void _goTrialTo(int count) {
    final trial = _trial;
    if (trial == null || count < 0 || count > _trialMoves.length || count == trialMoveCount) {
      return;
    }
    trial.syncGame(Game.replay(record.initialPosition, [...record.moves.take(_ply), ..._trialMoves.take(count)]));
  }

  void _onTrialChanged() {
    final trial = _trial;
    if (trial == null) {
      return;
    }
    // 놓아 본 수의 앞부분이면 오가기만 한 것이다. 아니면 새 수를 두었으므로 그 뒤의 수를 바꾼다.
    final played = trial.game.moves.sublist(_ply);
    if (!_isPrefix(played, _trialMoves)) {
      _trialMoves = played;
    }
    notifyListeners();
  }

  static bool _isPrefix(List<Move> prefix, List<Move> moves) {
    if (prefix.length > moves.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] != moves[i]) {
        return false;
      }
    }
    return true;
  }

  void _disposeTrial() {
    final trial = _trial;
    if (trial == null) {
      return;
    }
    trial.removeListener(_onTrialChanged);
    trial.dispose();
    _trial = null;
    _trialMoves = const [];
  }
}
