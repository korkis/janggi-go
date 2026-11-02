import 'package:flutter/foundation.dart';
import 'package:janggi_core/janggi_core.dart';

/// 상차림 화면의 상태. 상차림 화면이 만들고 `dispose()`한다.
///
/// 한 기기에서 양쪽을 두는 개발용 대국이므로 한이 먼저 고르고 이어서 초가 같은 화면에서 고른다.
class SetupManager extends ChangeNotifier {
  /// 아무것도 누르지 않았을 때 골라 둔 상차림(`docs/game/time.md`의 상차림 시간).
  static const defaultFormation = Formation.horseElephantHorseElephant;

  /// 각 진영 뒷줄에서 마·상이 놓이는 세로줄. 어느 진영이든 b, c, g, h 세로줄이다.
  static const _formationFiles = [1, 2, 6, 7];

  Side _chooser = Side.han;
  Formation _picked = defaultFormation;
  Formation? _hanFormation;
  Formation? _choFormation;

  /// 지금 상차림을 고르는 진영.
  Side get chooser => _chooser;

  /// 고르는 진영이 화면에서 골라 둔 상차림.
  Formation get picked => _picked;

  /// 한이 확정한 상차림. 아직 확정하지 않았으면 null이다.
  Formation? get hanFormation => _hanFormation;

  /// 양쪽이 모두 확정했는지 여부.
  bool get isDone => _hanFormation != null && _choFormation != null;

  /// 판에 보여줄 국면. 고르는 쪽은 골라 둔 상차림, 아직 고르지 않은 쪽은 기본 상차림으로 놓는다.
  Position get preview => createInitialPosition(
    cho: _choFormation ?? (_chooser == Side.cho ? _picked : defaultFormation),
    han: _hanFormation ?? _picked,
  );

  /// 양쪽이 확정한 상차림의 처음 국면. 확정 전이면 [StateError]를 던진다.
  Position get initialPosition {
    final cho = _choFormation;
    final han = _hanFormation;
    if (cho == null || han == null) {
      throw StateError('상차림이 아직 끝나지 않았다');
    }
    return createInitialPosition(cho: cho, han: han);
  }

  /// [side]의 마·상 네 자리.
  Set<Square> getFormationSquares(Side side) {
    final rank = side == Side.cho ? 0 : Square.rankCount - 1;
    return {for (final file in _formationFiles) Square(file, rank)};
  }

  /// 상차림을 골라 둔다. 양쪽이 이미 확정했으면 아무것도 하지 않는다.
  void pick(Formation formation) {
    if (isDone) {
      return;
    }
    _picked = formation;
    notifyListeners();
  }

  /// 골라 둔 상차림으로 확정한다. 한이 확정하면 초가 고를 차례가 된다.
  ///
  /// 양쪽이 이미 확정했으면 아무것도 하지 않는다. 화면이 넘어가기 전에 버튼을 한 번 더 누를 수 있기 때문이다.
  void confirm() {
    if (isDone) {
      return;
    }
    if (_chooser == Side.han) {
      _hanFormation = _picked;
      _chooser = Side.cho;
      _picked = defaultFormation;
    } else {
      _choFormation = _picked;
    }
    notifyListeners();
  }
}
