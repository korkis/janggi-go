import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/screens/game_screen.dart';
import 'package:janggigo/screens/review_screen.dart';
import 'package:janggigo/screens/setup_screen.dart';
import 'package:janggigo/theme/app_theme.dart';
import 'package:janggigo/widgets/board/board_geometry.dart';
import 'package:janggigo/widgets/board/board_view.dart';

/// 판의 [square] 교차점을 누른다. 판은 [BoardView] 안에서 비율을 지키며 가운데 놓인다.
Future<void> _tapSquare(WidgetTester tester, String square) async {
  final box = tester.renderObject<RenderBox>(find.byType(BoardView));
  final width = box.size.width.clamp(0.0, box.size.height * BoardGeometry.aspectRatio);
  final boardSize = Size(width, width / BoardGeometry.aspectRatio);
  final origin = box.localToGlobal(
    Offset((box.size.width - boardSize.width) / 2, (box.size.height - boardSize.height) / 2),
  );
  final center = BoardGeometry(boardSize, flipped: false).centerOf(Square.parse(square));
  await tester.tapAt(origin + center);
  await tester.pumpAndSettle();
}

Widget _gameApp(Position initialPosition) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Theme(
    data: gameTheme,
    child: GameScreen(initialPosition: initialPosition),
  ),
);

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

void main() {
  testWidgets('홈에서 상차림을 거쳐 대국을 시작하고 양쪽 한수쉼으로 끝낸 뒤 홈으로 돌아간다', (tester) async {
    _usePhoneView(tester);
    await tester.pumpWidget(const JanggigoApp());
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('상차림을 골라 주세요'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('마상상마'));
    await tester.pump();
    await tester.tap(find.text('이 상차림으로 정하기'));
    await tester.pumpAndSettle();
    expect(find.text('정했어요'), findsOneWidget);

    await tester.tap(find.text('이 상차림으로 정하기'));
    await tester.pumpAndSettle();
    expect(find.text('개발용 대국 · 0수'), findsOneWidget);

    await _tapSquare(tester, 'a4');
    await _tapSquare(tester, 'a5');
    expect(find.text('개발용 대국 · 1수'), findsOneWidget);

    // 한이 한수쉼을 하면 한의 정보 줄에도 같은 글자가 생기므로 버튼은 아이콘으로 찾는다.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle();

    expect(find.text('점수승'), findsOneWidget);
    expect(find.text('한 승리'), findsOneWidget);
    expect(find.text('양쪽이 연속으로 한수쉼을 해서 점수로 정했어요'), findsOneWidget);
    // 결과 창도 대국 화면과 같은 어두운 테마를 쓴다.
    expect(Theme.of(tester.element(find.text('한 승리'))).brightness, Brightness.dark);

    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('외통을 걸면 결과 창을 띄운다', (tester) async {
    _usePhoneView(tester);
    await tester.pumpWidget(_gameApp(Position.fromFen('4k4/R8/9/9/9/9/9/9/4K4/8R w')));

    await _tapSquare(tester, 'i1');
    await _tapSquare(tester, 'i10');

    expect(find.text('외통승'), findsOneWidget);
    expect(find.text('초 승리'), findsOneWidget);
  });

  testWidgets('결과 창에서 복기로 가서 수를 넘기고 놓아보기를 켰다 끈다', (tester) async {
    _usePhoneView(tester);
    await tester.pumpWidget(_gameApp(Position.fromFen('4k4/R8/9/9/9/9/9/9/4K4/8R w')));
    await _tapSquare(tester, 'i1');
    await _tapSquare(tester, 'i10');

    await tester.tap(find.text('복기하기'));
    await tester.pumpAndSettle();
    expect(find.text('복기'), findsOneWidget);
    expect(find.text('1 / 1수'), findsOneWidget);

    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 1수'), findsOneWidget);

    await tester.tap(find.text('놓아보기'));
    await tester.pumpAndSettle();
    await _tapSquare(tester, 'i1');
    await _tapSquare(tester, 'i5');
    final board = tester.widget<BoardView>(find.byType(BoardView));
    expect(board.position.pieceAt(Square.parse('i5')), const Piece(Side.cho, PieceType.chariot));

    await tester.tap(find.text('놓아보기'));
    await tester.pumpAndSettle();
    final restored = tester.widget<BoardView>(find.byType(BoardView));
    expect(restored.position.pieceAt(Square.parse('i1')), const Piece(Side.cho, PieceType.chariot));
    expect(find.text('0 / 1수'), findsOneWidget);
  });

  testWidgets('기권은 확인을 받은 뒤 차례인 쪽이 진다', (tester) async {
    _usePhoneView(tester);
    await tester.pumpWidget(
      _gameApp(
        createInitialPosition(cho: Formation.horseElephantHorseElephant, han: Formation.horseElephantHorseElephant),
      ),
    );

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기권'));
    await tester.pumpAndSettle();
    expect(find.text('초가 기권할까요?'), findsOneWidget);

    await tester.tap(find.text('기권하기'));
    await tester.pumpAndSettle();
    expect(find.text('기권승'), findsOneWidget);
    expect(find.text('한 승리'), findsOneWidget);
  });

  testWidgets('글자를 1.3배로 키워도 대국 화면이 넘치지 않는다', (tester) async {
    _usePhoneView(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      _gameApp(
        createInitialPosition(cho: Formation.horseElephantHorseElephant, han: Formation.horseElephantHorseElephant),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('글자를 1.3배로 키워도 상차림 화면이 넘치지 않는다', (tester) async {
    _usePhoneView(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Theme(data: gameTheme, child: const SetupScreen()),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('글자를 1.3배로 키워도 복기 화면이 넘치지 않는다', (tester) async {
    _usePhoneView(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // 수가 두 자리인 기보. 매번 둘 수 있는 첫 수를 둔다.
    var record = Game.start(
      createInitialPosition(cho: Formation.horseElephantHorseElephant, han: Formation.horseElephantHorseElephant),
    );
    while (record.moves.length < 87 && !record.isOver) {
      record = record.play(record.legalMoves().first);
    }
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Theme(
          data: gameTheme,
          child: ReviewScreen(record: record),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
