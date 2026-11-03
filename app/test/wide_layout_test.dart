import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/widgets/adaptive_layout.dart';
import 'package:janggigo/widgets/game_scaffold.dart';

import 'fakes.dart';

void _useView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

Widget _sizeProbe(Size size, void Function(LayoutSize) onSize) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: Builder(
      builder: (context) {
        onSize(getLayoutSize(context));
        return const SizedBox.shrink();
      },
    ),
  );
}

void main() {
  testWidgets('창 폭 600과 1024를 경계로 배치 구간을 나눈다', (tester) async {
    final cases = {
      599.0: LayoutSize.compact,
      600.0: LayoutSize.medium,
      1023.0: LayoutSize.medium,
      1024.0: LayoutSize.expanded,
    };
    for (final entry in cases.entries) {
      LayoutSize? size;
      await tester.pumpWidget(_sizeProbe(Size(entry.key, 800), (value) => size = value));
      expect(size, entry.value, reason: '폭 ${entry.key}');
    }
  });

  testWidgets('1024 이상은 왼쪽 메뉴를 두고, 대국 화면은 오른쪽 패널에 버튼을 모으고 결과 창을 가운데 띄운다', (tester) async {
    _useView(tester, const Size(1440, 900));
    setUpFakeApp();
    await tester.pumpWidget(const JanggigoApp());

    expect(find.byType(SideMenu), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    // 대국실은 홈 버튼 대신 왼쪽 메뉴에만 있다.
    expect(find.text('대국실'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SideMenu), findsNothing);
    expect(find.byType(GamePanel), findsOneWidget);
    await tester.tap(find.text('이 상차림으로 정하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 상차림으로 정하기'));
    await tester.pumpAndSettle();

    expect(find.byType(GamePanel), findsOneWidget);
    expect(find.text('개발용 대국 · 0수'), findsOneWidget);
    await tester.tap(find.text('기권'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기권하기'));
    await tester.pumpAndSettle();
    expect(find.text('기권승'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.text('복기하기'));
    await tester.pumpAndSettle();
    expect(find.text('복기'), findsOneWidget);
    expect(find.byType(GamePanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('600~1023은 왼쪽 메뉴 없이 일반 화면을 가운데 폭 480으로 모은다', (tester) async {
    _useView(tester, const Size(800, 900));
    setUpFakeApp();
    await tester.pumpWidget(const JanggigoApp());

    expect(find.byType(SideMenu), findsNothing);
    final scaffold = tester.getSize(find.byType(Scaffold).first);
    expect(scaffold.width, LayoutWidths.mediumContent);
  });
}
