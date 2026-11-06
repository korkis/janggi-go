import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/models/game_error_code.dart';
import 'package:janggigo/models/player_state.dart';
import 'package:janggigo/screens/game_screen.dart';
import 'package:janggigo/theme/app_theme.dart';
import 'package:janggigo/utils/app_exception.dart';
import 'package:janggigo/widgets/game_result.dart';
import 'package:janggigo/widgets/game_scaffold.dart';

import 'fakes.dart';
import 'online_game_fixtures.dart';

void _useView(WidgetTester tester, {double width = 320, double height = 680}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

Future<void> _pumpFor(WidgetTester tester, [Duration duration = const Duration(seconds: 1)]) async {
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> _clock({int baseMs = 300000, int periods = 3, int used = 0}) => {
  'baseMs': baseMs,
  'periods': periods,
  'extensionsUsed': used,
};

/// 내가(한, `opp`) 두는 진행 중인 대국. 초의 차례다.
Map<String, dynamic> _playing({
  Map<String, dynamic>? myClock,
  List<String> moves = const [],
  String? turn,
  Map<String, dynamic>? notice,
  Map<String, dynamic>? opponentClock,
  Map<String, dynamic>? result,
  int? endedAt,
}) {
  final json = buildGameJson(
    phase: result == null ? 'playing' : 'finished',
    setupTurn: 'cho',
    hanFormation: 'horseElephantHorseElephant',
    choFormation: 'horseElephantHorseElephant',
    turn: turn ?? 'cho',
    turnStartedAt: DateTime.now().millisecondsSinceEpoch,
    clock: {'cho': opponentClock ?? _clock(), 'han': myClock ?? _clock()},
    moves: moves,
    result: result,
    endedAt: endedAt,
  );
  if (notice != null) {
    (json['state'] as Map<String, dynamic>)['extensionNotice'] = notice;
  }
  return json;
}

Future<FakeApp> _openGame(WidgetTester tester, {int balance = 300, Map<String, dynamic>? game}) async {
  final fakes = setUpFakeApp();
  await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
  fakes.coinWallets.emit('opp', balance);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Theme(
        data: gameTheme,
        child: const GameScreen.online(gameId: 'g1'),
      ),
    ),
  );
  fakes.games.emit('g1', game ?? _playing());
  await _pumpFor(tester);
  return fakes;
}

Future<void> _closeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

Finder _barButton(String label) => find.widgetWithText(GameBarButton, label);

void main() {
  testWidgets('폭 320에 버튼 넷이 넘치지 않고 모두 누를 수 있는 크기다', (tester) async {
    _useView(tester);
    await _openGame(tester);

    for (final label in ['한수쉼', '시간 연장', '놓아보기', '메뉴']) {
      expect(_barButton(label), findsOneWidget);
      final size = tester.getSize(_barButton(label));
      expect(size.width, greaterThanOrEqualTo(minTouchSize), reason: label);
      expect(size.height, greaterThanOrEqualTo(minTouchSize), reason: label);
    }
    // 남은 횟수 배지
    expect(find.descendant(of: _barButton('시간 연장'), matching: find.text('2')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _closeGame(tester);
  });

  testWidgets('폭 320에서 글자를 1.3배로 키워도 버튼 줄이 넘치지 않는다', (tester) async {
    _useView(tester, height: 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openGame(tester);

    expect(_barButton('시간 연장'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _closeGame(tester);
  });

  testWidgets('시간 연장은 언제나 확인 창을 띄우고, 확인하면 지금까지 쓴 횟수와 값을 보낸다', (tester) async {
    _useView(tester);
    final fakes = await _openGame(tester);

    await tester.tap(_barButton('시간 연장'));
    await _pumpFor(tester);
    expect(find.text('30엽전을 내고 초읽기를 2회 늘릴까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await _pumpFor(tester);
    expect(fakes.games.calls.where((call) => call.startsWith('useTimeExtension')), isEmpty);

    // 초읽기 중에도 같다.
    fakes.games.emit('g1', _playing(myClock: _clock(baseMs: 0, periods: 1, used: 1), turn: 'han'));
    await _pumpFor(tester);
    await tester.tap(_barButton('시간 연장'));
    await _pumpFor(tester);
    await tester.tap(find.text('연장하기'));
    await _pumpFor(tester);
    expect(fakes.games.calls, contains('useTimeExtension g1 1 30'));
    await _closeGame(tester);
  });

  testWidgets('초읽기에 들어가면 시간 연장 버튼을 강조한다', (tester) async {
    _useView(tester);
    final fakes = await _openGame(tester);
    expect(tester.widget<GameBarButton>(_barButton('시간 연장')).emphasized, isFalse);

    fakes.games.emit('g1', _playing(myClock: _clock(baseMs: 0), turn: 'han'));
    await _pumpFor(tester);
    expect(tester.widget<GameBarButton>(_barButton('시간 연장')).emphasized, isTrue);
    await _closeGame(tester);
  });

  testWidgets('엽전이 모자라면 버튼이 흐리고, 누르면 확인 창 없이 엽전이 모자라요만 보여준다', (tester) async {
    _useView(tester);
    final fakes = await _openGame(tester, balance: 29);
    expect(tester.widget<GameBarButton>(_barButton('시간 연장')).dimmed, isTrue);
    expect(tester.widget<GameBarButton>(_barButton('놓아보기')).dimmed, isTrue);

    await tester.tap(_barButton('시간 연장'));
    await _pumpFor(tester);
    expect(find.text('엽전이 모자라요'), findsOneWidget);
    expect(find.text('연장하기'), findsNothing);
    await _pumpFor(tester, const Duration(seconds: 3));

    await tester.tap(_barButton('놓아보기'));
    await _pumpFor(tester);
    expect(find.text('엽전이 모자라요'), findsOneWidget);
    expect(fakes.games.calls.where((call) => call.startsWith('use')), isEmpty);
    await _closeGame(tester);
  });

  testWidgets('두 번 다 쓰면 시간 연장 버튼이 꺼진다', (tester) async {
    _useView(tester);
    await _openGame(tester, game: _playing(myClock: _clock(periods: 7, used: 2)));

    expect(tester.widget<GameBarButton>(_barButton('시간 연장')).onPressed, isNull);
    await _closeGame(tester);
  });

  testWidgets('서버가 거절하면 그 사유를 판 위에 알린다', (tester) async {
    _useView(tester);
    final fakes = await _openGame(tester);
    fakes.games.nextError = AppException.fromGameErrorCode(GameErrorCode.extensionLimit);

    await tester.tap(_barButton('시간 연장'));
    await _pumpFor(tester);
    await tester.tap(find.text('연장하기'));
    await _pumpFor(tester);

    expect(find.text('시간 연장을 더 쓸 수 없어요'), findsOneWidget);
    await _closeGame(tester);
  });

  testWidgets('상대가 시간을 연장하면 잠깐 알리고 초읽기 횟수가 바로 바뀌며, 화면을 열 때 있던 기록은 알리지 않는다', (tester) async {
    _useView(tester);
    const earlier = {'side': 'cho', 'at': 1000};
    final fakes = await _openGame(tester, game: _playing(notice: earlier));
    expect(find.text('상대가 시간을 연장했어요'), findsNothing);

    fakes.games.emit(
      'g1',
      _playing(notice: const {'side': 'cho', 'at': 2000}, opponentClock: _clock(periods: 5, used: 1)),
    );
    await _pumpFor(tester);
    expect(find.text('상대가 시간을 연장했어요'), findsOneWidget);
    expect(find.text('초읽기 5회'), findsOneWidget);

    await _pumpFor(tester, const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    await _closeGame(tester);
  });

  testWidgets('내 연장은 나에게 알리지 않는다', (tester) async {
    _useView(tester);
    final fakes = await _openGame(tester);

    fakes.games.emit('g1', _playing(notice: const {'side': 'han', 'at': 2000}, myClock: _clock(periods: 5, used: 1)));
    await _pumpFor(tester);
    expect(find.text('상대가 시간을 연장했어요'), findsNothing);
    await _closeGame(tester);
  });

  testWidgets('놓아보기는 값을 낸 뒤 놓아보기 막대와 양쪽 시계를 보여주고, 끝내고 다시 누르면 바로 연다', (tester) async {
    _useView(tester);
    final fakes = await _openGame(tester);

    await tester.tap(_barButton('놓아보기'));
    await _pumpFor(tester);
    expect(find.text('30엽전을 내면 이 판 내내 놓아보기를 쓸 수 있어요'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '놓아보기').last);
    await _pumpFor(tester);

    expect(fakes.games.calls, contains('useGamePractice g1 30'));
    expect(find.byType(TrialBar), findsOneWidget);
    expect(_barButton('시간 연장'), findsNothing);
    expect(find.text('초읽기 3회'), findsNWidgets(2));

    await tester.tap(find.text('끝내기'));
    await _pumpFor(tester);
    expect(find.byType(TrialBar), findsNothing);

    await tester.tap(_barButton('놓아보기'));
    await _pumpFor(tester);
    expect(find.byType(TrialBar), findsOneWidget);
    expect(fakes.games.calls.where((call) => call.startsWith('useGamePractice')).length, 1);
    await _closeGame(tester);
  });

  testWidgets('앱을 다시 켜도 값을 낸 판이면 확인 창 없이 연다', (tester) async {
    _useView(tester);
    final fakes = setUpFakeApp();
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    fakes.coinWallets.emit('opp', 0);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Theme(
          data: gameTheme,
          child: const GameScreen.online(gameId: 'g1'),
        ),
      ),
    );
    fakes.playerStates.emit(
      'opp',
      PlayerState(
        roomId: null,
        gameId: 'g1',
        lastGameId: null,
        outgoingChallengeId: null,
        incomingChallengeId: null,
        setupDraft: null,
        lastRankChange: null,
        gamePracticeGameId: 'g1',
        quickQueueJoinedAt: null,
        updatedAt: DateTime.utc(2026, 11, 6),
      ),
    );
    fakes.games.emit('g1', _playing());
    await _pumpFor(tester);
    expect(tester.widget<GameBarButton>(_barButton('놓아보기')).dimmed, isFalse);

    await tester.tap(_barButton('놓아보기'));
    await _pumpFor(tester);
    expect(find.byType(TrialBar), findsOneWidget);
    expect(fakes.games.calls.where((call) => call.startsWith('useGamePractice')), isEmpty);

    fakes.playerStates.emit('opp', null);
    await _closeGame(tester);
  });

  testWidgets('놓아보기 중 상대가 두면 글자 없이 판은 그대로 두고 차례 표시만 넘어오며, 대국이 끝나면 결과로 간다', (tester) async {
    _useView(tester);
    final fakes = await _openGame(tester);
    await tester.tap(_barButton('놓아보기'));
    await _pumpFor(tester);
    await tester.tap(find.widgetWithText(TextButton, '놓아보기').last);
    await _pumpFor(tester);

    fakes.games.emit('g1', _playing(moves: const ['pass'], turn: 'han'));
    await _pumpFor(tester);
    expect(find.byType(TrialBar), findsOneWidget);
    expect(find.text('상대가 두었어요'), findsNothing);

    fakes.games.emit(
      'g1',
      _playing(
        moves: const ['pass'],
        turn: 'han',
        result: const {'winner': 'cho', 'reason': 'resignation', 'choScore': 72.0, 'hanScore': 73.5},
        endedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _pumpFor(tester);
    expect(find.byType(TrialBar), findsNothing);
    expect(find.byType(ReviewBar), findsOneWidget);
    await _pumpFor(tester, const Duration(seconds: 3));
    await _closeGame(tester);
  });

  testWidgets('스위치를 끄면 그 버튼이 사라진다', (tester) async {
    _useView(tester);
    final fakes = setUpFakeApp();
    fakes.configs.timeExtensionEnabled = false;
    fakes.configs.gamePracticeEnabled = false;
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Theme(
          data: gameTheme,
          child: const GameScreen.online(gameId: 'g1'),
        ),
      ),
    );
    fakes.games.emit('g1', _playing());
    await _pumpFor(tester);

    expect(_barButton('시간 연장'), findsNothing);
    expect(_barButton('놓아보기'), findsNothing);
    expect(_barButton('메뉴'), findsOneWidget);
    await _closeGame(tester);
  });
}
