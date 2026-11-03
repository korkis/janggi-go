import 'package:flutter/foundation.dart';
import 'package:janggi_core/janggi_core.dart';

import 'board_manager.dart';

/// 복기 화면의 상태. 복기 화면이 만들고 `dispose()`한다.
///
/// 기보의 몇 수째를 보는지와 놓아보기 판을 가진다. 놓아보기를 켜면 지금 보는 국면에서 이어 두는
/// [BoardManager]를 만들고, 끄면 그 판을 버리고 원래 기보 위치로 돌아간다.
class ReviewManager extends ChangeNotifier {
  /// 복기하는 대국. 처음 국면과 둔 수가 들어 있다.
  final Game record;

  /// 지금 보는 국면까지 둔 수의 개수. 0이면 처음 국면이다.
  int _ply;

  /// 놓아보기 판. 놓아보기를 끈 상태면 null이다.
  BoardManager? _trial;

  /// [trying]이면 놓아보기를 켠 채로 시작한다(새 판에서 놓아보기).
  ReviewManager({required this.record, bool trying = false}) : _ply = record.moves.length {
    if (trying) {
      toggleTrial();
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

  /// 놓아보기에서 둔 수의 개수.
  int get trialMoveCount => _trial == null ? 0 : _trial!.moveCount - _ply;

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

  void goFirst() => goTo(0);

  void goPrevious() => goTo(_ply - 1);

  void goNext() => goTo(_ply + 1);

  void goLast() => goTo(totalMoves);

  /// 놓아보기를 켜고 끈다. 끄면 놓아보기에서 둔 수를 버리고 켜기 전의 기보 위치로 돌아간다.
  void toggleTrial() {
    if (trying) {
      _disposeTrial();
    } else {
      // 반복수 판정에 지나온 수가 필요하므로 처음부터 지금 위치까지 다시 둔 대국에서 이어 둔다.
      final trial = BoardManager.fromGame(Game.replay(record.initialPosition, record.moves.take(_ply)));
      trial.addListener(_onTrialChanged);
      _trial = trial;
    }
    notifyListeners();
  }

  /// 놓아보기 중에 판의 교차점을 눌렀을 때. 놓아보기를 끈 상태면 아무것도 하지 않는다.
  void tapSquare(Square square) {
    _trial?.tapSquare(square);
  }

  void _onTrialChanged() {
    notifyListeners();
  }

  void _disposeTrial() {
    final trial = _trial;
    if (trial == null) {
      return;
    }
    trial.removeListener(_onTrialChanged);
    trial.dispose();
    _trial = null;
  }
}
