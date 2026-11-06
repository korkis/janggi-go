import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/coin_wallet.dart';
import 'package:janggigo/models/user_profile.dart';

import 'fakes.dart';

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

Future<void> _pumpFor(WidgetTester tester) async {
  for (var elapsed = 0; elapsed < 10; elapsed++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

UserProfile _profile(String nickname) => UserProfile(
  nickname: nickname,
  rankLevel: 1,
  stats: const UserStats(games: 0, wins: 0, losses: 0),
  createdAt: DateTime.utc(2026, 11, 6),
);

void main() {
  testWidgets('로그인하면 내 카드에 잔액을 보여주고 바뀌면 따라 바꾼다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['me'] = _profile('나');
    fakes.coinWallets.emit('me', 1330);
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    await managers.authManager.ensureProfileLoaded();

    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(find.text('1,330'), findsOneWidget);
    expect(find.byIcon(Icons.toll), findsOneWidget);

    fakes.coinWallets.emit('me', 320);
    await _pumpFor(tester);
    expect(find.text('320'), findsOneWidget);
  });

  testWidgets('로그인하지 않았으면 잔액을 보여주지 않고 출석도 부르지 않는다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();

    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(find.byIcon(Icons.toll), findsNothing);
    expect(fakes.coinWallets.attendanceCalls, 0);
  });

  testWidgets('닉네임을 정하기 전에는 출석을 부르지 않는다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    await managers.authManager.ensureProfileLoaded();

    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(fakes.coinWallets.attendanceCalls, 0);
  });

  testWidgets('앱을 열면 출석을 받고 아래에 알린다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['me'] = _profile('나');
    fakes.coinWallets.nextAttendance = const AttendanceResult(granted: true, amount: 30);
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');

    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(fakes.coinWallets.attendanceCalls, 1);
    expect(find.text('출석 +30엽전'), findsOneWidget);
  });

  testWidgets('오늘 이미 받았으면 알리지 않고 다시 부르지 않는다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['me'] = _profile('나');
    managers.coinManager.observeAppLifecycle();
    addTearDown(managers.coinManager.dispose);
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(find.textContaining('출석'), findsNothing);
    expect(fakes.coinWallets.attendanceCalls, 1);

    // 다른 앱에 갔다 돌아와도 같은 날이면 부르지 않는다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFor(tester);
    expect(fakes.coinWallets.attendanceCalls, 1);
  });

  testWidgets('출석이 실패해도 앱은 그대로이고 돌아올 때 다시 부른다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['me'] = _profile('나');
    fakes.coinWallets.nextAttendanceError = StateError('네트워크 오류');
    managers.coinManager.observeAppLifecycle();
    addTearDown(managers.coinManager.dispose);
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(fakes.coinWallets.attendanceCalls, 1);
    expect(find.textContaining('출석'), findsNothing);

    fakes.coinWallets.nextAttendance = const AttendanceResult(granted: true, amount: 100);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFor(tester);

    expect(fakes.coinWallets.attendanceCalls, 2);
    expect(find.text('출석 +100엽전'), findsOneWidget);
  });
}
