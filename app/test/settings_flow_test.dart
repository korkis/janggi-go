import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/app_language.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/profile_screen.dart';

import 'fakes.dart';

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

/// 화면 전환과 타이머가 있어 `pumpAndSettle` 대신 시간을 정해 흘린다.
Future<void> _pumpFor(WidgetTester tester, [Duration duration = const Duration(seconds: 1)]) async {
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _pumpFor(tester);
}

void main() {
  testWidgets('내 정보의 설정에서 언어를 바꾸면 다시 켜지 않아도 바로 바뀌고 기기에 저장한다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['me'] = UserProfile(
      nickname: '나',
      rankLevel: 1,
      stats: const UserStats(games: 0, wins: 0, losses: 0),
      createdAt: DateTime.utc(2026, 11, 4),
    );
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    await managers.authManager.ensureProfileLoaded();
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    // 내 정보 화면을 닫을 때까지 끝나지 않으므로 기다리지 않는다.
    unawaited(ProfileScreen.open(tester.element(find.byType(Scaffold).first)));
    await _pumpFor(tester);
    await _tap(tester, find.text('설정'));
    expect(find.text('언어'), findsOneWidget);
    expect(find.text('기기 설정 따름'), findsOneWidget);

    await _tap(tester, find.text('English'));
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Use device setting'), findsOneWidget);
    expect(fakes.deviceSettings.language, AppLanguage.en);

    await _tap(tester, find.text('Use device setting'));
    expect(find.text('언어'), findsOneWidget);
    expect(fakes.deviceSettings.language, AppLanguage.system);
  });

  testWidgets('앱을 켤 때 기기에 저장한 언어를 읽는다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.deviceSettings.language = AppLanguage.en;
    await managers.languageManager.load();
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(find.text('시작하기'), findsNothing);
    expect(managers.languageManager.locale, const Locale('en'));
  });
}
