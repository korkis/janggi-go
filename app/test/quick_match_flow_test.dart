import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/models/player_state.dart';
import 'package:janggigo/models/user_private.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/game_screen.dart';
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

/// 물결과 기다린 시간 타이머가 있어 `pumpAndSettle` 대신 시간을 정해 흘린다.
Future<void> _pumpFor(WidgetTester tester, [Duration duration = const Duration(seconds: 1)]) async {
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

PlayerState _playerState({String? gameId, String? lastGameId, RankChange? lastRankChange}) {
  return PlayerState(
    roomId: null,
    gameId: gameId,
    lastGameId: lastGameId,
    outgoingChallengeId: null,
    incomingChallengeId: null,
    setupDraft: null,
    lastRankChange: lastRankChange,
    quickQueueJoinedAt: null,
    updatedAt: DateTime.utc(2026, 11, 2),
  );
}

UserPrivate _userPrivate({required double rankProgress, required int? winsToNextRank}) {
  return UserPrivate(
    challengesEnabled: true,
    rankProgress: rankProgress,
    winsToNextRank: winsToNextRank,
    nicknameChangeCount: 0,
    nicknameChangedAt: null,
    sanction: null,
  );
}

UserProfile _profile(String nickname, int rankLevel) {
  return UserProfile(
    nickname: nickname,
    rankLevel: rankLevel,
    stats: const UserStats(games: 0, wins: 0, losses: 0),
    createdAt: DateTime.utc(2026, 11, 2),
  );
}

/// 빠른 대국에서 끝난 대국. 나(`opp`)는 한이다.
Map<String, dynamic> _finishedQuickGame({Map<String, dynamic>? rematch}) {
  return buildGameJson(
    mode: 'quick',
    rated: true,
    phase: 'finished',
    setupTurn: 'cho',
    hanFormation: 'horseElephantHorseElephant',
    choFormation: 'horseElephantHorseElephant',
    turn: 'cho',
    turnStartedAt: 1030000,
    result: {'winner': 'han', 'reason': 'resignation', 'choScore': 72, 'hanScore': 73.5},
    endedAt: 1040000,
    rematch: rematch,
  );
}

Widget _buildGameScreen() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Theme(
      data: gameTheme,
      child: const GameScreen.online(gameId: 'g1'),
    ),
  );
}

void main() {
  testWidgets('홈 내 카드에 급수, 진행 막대, 다음 급수까지의 어림 승수를 보여준다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['opp'] = _profile('한사람', 2);
    fakes.userPrivates.emit('opp', _userPrivate(rankProgress: 0.4, winsToNextRank: 2));
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(find.text('17급'), findsOneWidget);
    expect(find.text('16급까지 약 2승'), findsOneWidget);

    // 급수 대국을 두지 않아 어림 승수가 없으면 막대만 보여준다.
    fakes.userPrivates.emit('opp', _userPrivate(rankProgress: 0, winsToNextRank: null));
    await _pumpFor(tester);
    expect(find.textContaining('까지 약'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('빠른 대국을 누르면 상대를 찾고, 대국이 생기면 바로 상차림 창을 띄운다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['opp'] = _profile('한사람', 1);
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    await tester.tap(find.text('빠른 대국'));
    await _pumpFor(tester);
    expect(fakes.games.calls, ['joinQuickQueue']);
    expect(find.text('상대를 찾고 있어요'), findsOneWidget);
    expect(find.text('그만 찾기'), findsOneWidget);
    expect(find.text('장기 규칙'), findsOneWidget);

    fakes.playerStates.emit('opp', _playerState(gameId: 'g1'));
    fakes.games.emit('g1', buildGameJson(mode: 'quick', rated: true, startsAt: DateTime.now().millisecondsSinceEpoch));
    await _pumpFor(tester);
    expect(find.text('상차림을 골라 주세요'), findsOneWidget);
    expect(find.text('초me · 18급'), findsNWidgets(2));
    expect(find.text('나는 한 · 나중에 둬요'), findsOneWidget);
    expect(find.text('이 상차림으로 정하기'), findsOneWidget);

    fakes.playerStates.emit('opp', null);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('그만 찾기를 누르면 대기열에서 나와 홈으로 돌아간다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['opp'] = _profile('한사람', 1);
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    await tester.tap(find.text('빠른 대국'));
    await _pumpFor(tester);
    await tester.tap(find.text('그만 찾기'));
    await _pumpFor(tester);
    expect(fakes.games.calls, ['joinQuickQueue', 'leaveQuickQueue']);
    expect(find.text('상대를 찾고 있어요'), findsNothing);
    expect(find.text('빠른 대국'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('빠른 대국 결과 창은 급수 변동과 한 판 더를 보여주고, 두 사람이 다시 두기를 누르면 새 대국으로 간다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    fakes.userPrivates.emit('opp', _userPrivate(rankProgress: 0.6, winsToNextRank: 1));
    fakes.playerStates.emit(
      'opp',
      _playerState(
        lastGameId: 'g1',
        lastRankChange: const RankChange(
          gameId: 'g1',
          rankLevelBefore: 1,
          rankLevelAfter: 2,
          rankProgressBefore: 0.8,
          rankProgressAfter: 0.6,
        ),
      ),
    );
    await tester.pumpWidget(_buildGameScreen());
    fakes.games.emit('g1', _finishedQuickGame());
    await _pumpFor(tester);

    expect(find.text('기권승'), findsOneWidget);
    expect(find.text('한 승리!'), findsOneWidget);
    expect(find.text('17급으로 올랐어요'), findsOneWidget);
    expect(find.text('16급까지 약 1승'), findsOneWidget);
    expect(find.text('한 판 더'), findsOneWidget);

    // 상대가 먼저 눌렀다.
    fakes.games.emit('g1', _finishedQuickGame(rematch: {'cho': true}));
    await _pumpFor(tester);
    expect(find.text('상대가 다시 두기를 원해요'), findsOneWidget);

    await tester.tap(find.text('다시 두기'));
    await _pumpFor(tester);
    expect(fakes.games.calls, ['requestRematch g1']);

    // 서버가 새 대국을 만들고 나를 묶으면 새 대국의 상차림으로 간다.
    fakes.games.emit('g1', _finishedQuickGame(rematch: {'cho': true, 'han': true, 'gameId': 'g2'}));
    fakes.games.emit('g2', buildGameJson(cho: 'opp', han: 'me', mode: 'quick', rated: true));
    fakes.playerStates.emit('opp', _playerState(gameId: 'g2', lastGameId: 'g1'));
    await _pumpFor(tester);
    expect(find.text('상차림을 골라 주세요'), findsOneWidget);
    expect(fakes.games.calls, isNot(contains('leaveResult g1')));

    fakes.playerStates.emit('opp', null);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('상대가 나갔거나 다시 두기 횟수에 닿으면 다시 두기를 끄고, 홈으로 가면 결과 화면을 나간다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    await fakes.auth.signInWithEmail(email: 'opp', password: 'password');
    await tester.pumpWidget(_buildGameScreen());
    fakes.games.emit('g1', _finishedQuickGame(rematch: {'blocked': true}));
    await _pumpFor(tester);
    expect(find.text('같은 상대와는 더 다시 둘 수 없어요'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '다시 두기')).onPressed, isNull);

    fakes.games.emit('g1', _finishedQuickGame(rematch: {'cho': true, 'cancelled': true}));
    await _pumpFor(tester);
    expect(find.text('상대가 나가서 다시 둘 수 없어요'), findsOneWidget);

    await tester.tap(find.text('홈으로'));
    await _pumpFor(tester);
    expect(fakes.games.calls, ['leaveResult g1']);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
