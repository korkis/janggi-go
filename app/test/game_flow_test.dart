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
import 'package:janggigo/widgets/board/check_effect.dart';
import 'package:janggigo/widgets/game_scaffold.dart';
import 'package:janggigo/widgets/player_bar.dart';

import 'fakes.dart';

/// 판의 [square] 교차점을 누른다. 판은 [BoardView] 안에서 비율을 지키며 가운데 놓인다.
Future<void> _tapSquare(WidgetTester tester, String square) async {
  await _tapSquareOnly(tester, square);
  await tester.pumpAndSettle();
}

/// [_tapSquare]와 같지만 애니메이션이 끝나기를 기다리지 않는다. 장군인 동안은 궁 위 도장이 계속 움직인다.
Future<void> _tapSquareOnly(WidgetTester tester, String square) async {
  final box = tester.renderObject<RenderBox>(find.byType(BoardView));
  final width = box.size.width.clamp(0.0, box.size.height * BoardGeometry.aspectRatio);
  final boardSize = Size(width, width / BoardGeometry.aspectRatio);
  final origin = box.localToGlobal(
    Offset((box.size.width - boardSize.width) / 2, (box.size.height - boardSize.height) / 2),
  );
  final center = BoardGeometry(boardSize, flipped: false).centerOf(Square.parse(square));
  await tester.tapAt(origin + center);
  await tester.pump();
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
    setUpFakeApp();
    await tester.pumpWidget(const JanggigoApp());
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('상차림을 골라 주세요'), findsOneWidget);
    // 상차림 창 뒤의 막은 화면 일부가 아니라 전체를 덮고, 창은 판의 내 쪽 마·상 줄 위에 놓인다.
    final scrim = find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == GameColors.scrim);
    expect(tester.getRect(scrim), Offset.zero & const Size(390, 844));
    final boardRect = tester.getRect(find.byType(BoardView));
    final cell = boardRect.width / BoardGeometry.widthCells;
    expect(tester.getRect(find.text('이 상차림으로 정하기')).bottom, lessThan(boardRect.bottom - cell * 2));
    await tester.tap(find.bySemanticsLabel('마상상마'));
    await tester.pump();
    await tester.tap(find.text('이 상차림으로 정하기'));
    await tester.pumpAndSettle();
    expect(find.text('상대가 정했어요'), findsOneWidget);

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

    // 결과 창 없이 같은 화면이 복기 모드가 되고, 결과 도장이 머리줄 결과 칩으로 올라간다.
    expect(find.text('한 승리 · 점수승'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('한 승리 · 점수승'))).brightness, Brightness.dark);
    expect(find.text('복기 3 / 3수'), findsOneWidget);

    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('외통을 걸면 판 가운데에 결과 도장을 찍고 머리줄 결과 칩으로 올린다', (tester) async {
    _usePhoneView(tester);
    await tester.pumpWidget(_gameApp(Position.fromFen('4k4/R8/9/9/9/9/9/9/4K4/8R w')));

    await _tapSquare(tester, 'i1');
    await _tapSquareOnly(tester, 'i10');
    await tester.pump(const Duration(milliseconds: 800));
    // 한 기기에서 양쪽을 두면 이긴 쪽 기준이라 승리 도장이다.
    expect(find.text('승'), findsOneWidget);
    expect(find.text('외통승 · 1수 · 0분 0초'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('승'), findsNothing);
    expect(find.text('초 승리 · 외통승'), findsOneWidget);
  });

  testWidgets('장군을 걸 때마다 판을 어둡게 하지 않고 큰 도장을 찍고, 장군을 건 기물에 빨간 테두리를 둔다', (tester) async {
    _usePhoneView(tester);
    // 초 차 a1, 초 궁 f1, 한 궁 d10.
    await tester.pumpWidget(_gameApp(Position.fromFen('3k5/9/9/9/9/9/9/9/9/R4K3 w')));
    final bigStamp = find.descendant(of: find.byType(BigCheckStamp), matching: find.text('장군'));
    final scrim = find.descendant(
      of: find.byType(BoardView),
      matching: find.byWidgetPredicate((widget) => widget is ColoredBox),
    );
    List<Square>? checkers() {
      for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
        final painter = paint.painter;
        if (painter is CheckerRingPainter) {
          return painter.checkers;
        }
      }
      return null;
    }

    await _tapSquare(tester, 'a1');
    await _tapSquareOnly(tester, 'd1');
    await tester.pump(const Duration(milliseconds: 1000));
    expect(bigStamp, findsOneWidget);
    expect(scrim, findsNothing);
    expect(checkers(), [Square.parse('d1')]);
    // 정보 줄에는 장군 표시를 두지 않는다.
    expect(find.widgetWithText(PlayerBadge, '장군'), findsNothing);
    await tester.pumpAndSettle();
    expect(bigStamp, findsNothing);
    // 도장이 사라져도 장군이 풀릴 때까지 장군을 건 기물의 테두리는 남는다.
    expect(checkers(), [Square.parse('d1')]);

    await _tapSquare(tester, 'd10');
    await _tapSquare(tester, 'e10');
    expect(checkers(), isNull);

    // 두 번째 장군도 큰 도장을 찍는다.
    await _tapSquare(tester, 'd1');
    await _tapSquareOnly(tester, 'e1');
    await tester.pump(const Duration(milliseconds: 1000));
    expect(bigStamp, findsOneWidget);
    expect(checkers(), [Square.parse('e1')]);
    await tester.pumpAndSettle();
  });

  testWidgets('대국이 끝나면 같은 화면에서 마지막 수부터 복기한다', (tester) async {
    _usePhoneView(tester);
    await tester.pumpWidget(_gameApp(Position.fromFen('4k4/R8/9/9/9/9/9/9/4K4/8R w')));
    await _tapSquare(tester, 'i1');
    await _tapSquare(tester, 'i10');

    expect(find.text('복기 1 / 1수'), findsOneWidget);
    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(find.text('복기 0 / 1수'), findsOneWidget);
    final board = tester.widget<BoardView>(find.byType(BoardView));
    expect(board.position.pieceAt(Square.parse('i1')), const Piece(Side.cho, PieceType.chariot));
    expect(find.text('재대국 신청'), findsOneWidget);

    // 놓아보기를 켜면 판에 직접 두고 수 이동은 끈다. 끄면 원래 기보 위치로 돌아간다.
    await tester.tap(find.text('놓아보기'));
    await tester.pumpAndSettle();
    expect(tester.widget<GameBarButton>(find.widgetWithText(GameBarButton, '다음')).onPressed, isNull);
    await _tapSquare(tester, 'i1');
    await _tapSquare(tester, 'i5');
    final trial = tester.widget<BoardView>(find.byType(BoardView));
    expect(trial.position.pieceAt(Square.parse('i5')), const Piece(Side.cho, PieceType.chariot));

    await tester.tap(find.text('놓아보기'));
    await tester.pumpAndSettle();
    final restored = tester.widget<BoardView>(find.byType(BoardView));
    expect(restored.position.pieceAt(Square.parse('i1')), const Piece(Side.cho, PieceType.chariot));
    expect(find.text('복기 0 / 1수'), findsOneWidget);
  });

  testWidgets('복기 화면에서 수를 넘기고 놓아보기를 켰다 끈다', (tester) async {
    _usePhoneView(tester);
    final record = Game.start(Position.fromFen('4k4/R8/9/9/9/9/9/9/4K4/8R w')).play(Move.parse('i1i10'));
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
    expect(find.text('한 승리 · 기권승'), findsOneWidget);
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
