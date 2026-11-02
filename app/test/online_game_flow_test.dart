import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/models/player_state.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/game_screen.dart';
import 'package:janggigo/screens/setup_screen.dart';
import 'package:janggigo/theme/app_theme.dart';

import 'fakes.dart';
import 'online_game_fixtures.dart';

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

/// 화면 전환과 시계 타이머가 있어 `pumpAndSettle` 대신 시간을 정해 흘린다.
Future<void> _pumpFor(WidgetTester tester, [Duration duration = const Duration(seconds: 1)]) async {
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('온라인 상차림을 확정하면 대국 화면으로 넘어가고, 서버 결과가 오면 결과 창을 띄운다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Theme(
          data: gameTheme,
          child: const SetupScreen.online(gameId: 'g1'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    fakes.games.emit('g1', buildGameJson());
    await _pumpFor(tester);
    expect(find.text('상차림을 골라 주세요'), findsOneWidget);
    expect(find.text('한opp · 1단'), findsOneWidget);
    expect(find.text('초me · 18급'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('마상상마'));
    await tester.tap(find.text('이 상차림으로 정하기'));
    await _pumpFor(tester);
    expect(fakes.games.calls, [
      'setFormation g1 horseElephantElephantHorse false',
      'setFormation g1 horseElephantElephantHorse true',
    ]);

    fakes.games.emit('g1', buildGameJson(setupTurn: 'cho', hanFormation: 'horseElephantElephantHorse'));
    await _pumpFor(tester);
    expect(find.text('상대가 고르고 있어요'), findsOneWidget);

    fakes.games.emit(
      'g1',
      buildGameJson(
        phase: 'playing',
        setupTurn: 'cho',
        hanFormation: 'horseElephantHorseElephant',
        choFormation: 'horseElephantHorseElephant',
        turn: 'cho',
        turnStartedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _pumpFor(tester);
    expect(find.text('온라인 대국 · 0수'), findsOneWidget);
    expect(find.text('5:00'), findsNWidgets(2));
    expect(find.text('초읽기 3회'), findsNWidgets(2));

    fakes.games.emit(
      'g1',
      buildGameJson(
        phase: 'finished',
        setupTurn: 'cho',
        hanFormation: 'horseElephantHorseElephant',
        choFormation: 'horseElephantHorseElephant',
        turn: 'cho',
        turnStartedAt: 1030000,
        result: {'winner': 'han', 'reason': 'resignation', 'choScore': 72, 'hanScore': 73.5},
        endedAt: 1040000,
      ),
    );
    await _pumpFor(tester);
    expect(find.text('기권승'), findsOneWidget);
    expect(find.text('한 승리'), findsOneWidget);
    expect(find.text('다시 두기'), findsNothing);

    // 화면을 닫아 시계 타이머를 멈춘다.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('홈의 개발용 온라인 대국 카드로 대국을 만들고, 대국이 생기면 상차림으로 간다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['opp'] = UserProfile(
      nickname: '한사람',
      rankLevel: 1,
      stats: const UserStats(games: 0, wins: 0, losses: 0),
      createdAt: DateTime.utc(2026, 11, 2),
    );
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    await tester.scrollUntilVisible(find.text('대국 만들기'), 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), '초사람');
    await tester.tap(find.text('대국 만들기'));
    await _pumpFor(tester);
    expect(fakes.games.calls, ['createDevGame 초사람 random']);

    fakes.games.emit('g1', buildGameJson());
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
        quickQueueJoinedAt: null,
        updatedAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await _pumpFor(tester);
    expect(find.text('상차림을 골라 주세요'), findsOneWidget);

    // 대국이 풀리면 lastSeenAt 갱신을 멈춘다. 화면도 닫아 시계 타이머를 멈춘다.
    fakes.playerStates.emit('opp', null);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('상대 연결이 끊기면 상대 정보 줄에 남은 시간을, 내 연결이 끊기면 판 위에 다시 연결하는 중을 보여준다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
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
    final now = DateTime.now().millisecondsSinceEpoch;
    fakes.games.emit(
      'g1',
      buildGameJson(
        phase: 'playing',
        setupTurn: 'cho',
        hanFormation: 'horseElephantHorseElephant',
        choFormation: 'horseElephantHorseElephant',
        turn: 'cho',
        turnStartedAt: now,
        disconnect: {
          'cho': {'usedMs': 4000, 'since': now - 5000},
          'han': {'usedMs': 0},
        },
      ),
    );
    await _pumpFor(tester);
    // 30초 - 앞서 끊긴 4초 - 지금 끊긴 5초
    expect(find.textContaining(RegExp(r'^연결이 끊겼어요 2[01]초$')), findsOneWidget);
    expect(find.text('다시 연결하는 중'), findsNothing);

    fakes.connections.setConnected(false);
    await _pumpFor(tester);
    expect(find.text('다시 연결하는 중'), findsOneWidget);
    fakes.connections.setConnected(true);
    await _pumpFor(tester);
    expect(find.text('다시 연결하는 중'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('진행 중인 대국이 있으면 홈 맨 위의 대국으로 돌아가기로 대국에 다시 들어간다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['opp'] = UserProfile(
      nickname: '한사람',
      rankLevel: 1,
      stats: const UserStats(games: 0, wins: 0, losses: 0),
      createdAt: DateTime.utc(2026, 11, 2),
    );
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    // 앱을 다시 켠 것처럼 진행 중인 대국이 이미 있다.
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
        quickQueueJoinedAt: null,
        updatedAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    expect(find.text('대국 만들기'), findsNothing);

    await tester.tap(find.text('대국으로 돌아가기'));
    fakes.games.emit('g1', buildGameJson());
    await _pumpFor(tester);
    expect(find.text('상차림을 골라 주세요'), findsOneWidget);

    fakes.playerStates.emit('opp', null);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
