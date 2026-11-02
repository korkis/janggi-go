import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/managers/setup_manager.dart';

void main() {
  group('SetupManager', () {
    test('한이 먼저 고르고 이어서 초가 고른다', () {
      final setup = SetupManager();
      expect(setup.chooser, Side.han);

      setup
        ..pick(Formation.horseElephantElephantHorse)
        ..confirm();
      expect(setup.chooser, Side.cho);
      expect(setup.hanFormation, Formation.horseElephantElephantHorse);
      expect(setup.picked, SetupManager.defaultFormation);
      expect(setup.isDone, isFalse);

      setup
        ..pick(Formation.elephantHorseHorseElephant)
        ..confirm();
      expect(setup.isDone, isTrue);
      expect(
        setup.initialPosition,
        createInitialPosition(cho: Formation.elephantHorseHorseElephant, han: Formation.horseElephantElephantHorse),
      );
    });

    test('판에는 고르는 쪽이 골라 둔 상차림을 놓는다', () {
      final setup = SetupManager()..pick(Formation.elephantHorseElephantHorse);

      expect(
        setup.preview,
        createInitialPosition(cho: SetupManager.defaultFormation, han: Formation.elephantHorseElephantHorse),
      );
    });

    test('마·상 네 자리', () {
      final setup = SetupManager();

      expect(setup.getFormationSquares(Side.cho), {
        for (final s in ['b1', 'c1', 'g1', 'h1']) Square.parse(s),
      });
      expect(setup.getFormationSquares(Side.han), {
        for (final s in ['b10', 'c10', 'g10', 'h10']) Square.parse(s),
      });
    });

    test('양쪽이 확정하기 전에는 처음 국면을 만들 수 없다', () {
      expect(() => SetupManager().initialPosition, throwsStateError);
    });
  });
}
