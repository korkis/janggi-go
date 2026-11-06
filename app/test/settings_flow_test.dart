import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/app_language.dart';
import 'package:janggigo/models/sign_in_method.dart';
import 'package:janggigo/models/user_private.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/home_screen.dart';
import 'package:janggigo/screens/lobby_screen.dart';
import 'package:janggigo/screens/profile_screen.dart';
import 'package:janggigo/screens/records_screen.dart';
import 'package:janggigo/screens/settings_screen.dart';
import 'package:janggigo/screens/spectate_list_screen.dart';
import 'package:janggigo/widgets/adaptive_layout.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fakes.dart';

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

void _useView(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

Future<FakeApp> _signIn() async {
  final fakes = setUpFakeApp();
  fakes.users.profiles['me'] = UserProfile(
    nickname: '나',
    rankLevel: 1,
    stats: const UserStats(games: 0, wins: 0, losses: 0),
    createdAt: DateTime.utc(2026, 11, 4),
  );
  fakes.userPrivates.emit(
    'me',
    const UserPrivate(
      challengesEnabled: true,
      rankProgress: 0.5,
      winsToNextRank: 3,
      nicknameChangeCount: 0,
      nicknameChangedAt: null,
      sanction: null,
    ),
  );
  await fakes.auth.signInWithEmail(email: 'me', password: 'password');
  await managers.authManager.ensureProfileLoaded();
  return fakes;
}

Finder _inTabBar(String label) => find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

Finder _inSideMenu(String label) => find.descendant(of: find.byType(SideMenu), matching: find.text(label));

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '장기고',
      packageName: 'janggigo',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  testWidgets('내 정보의 설정에서 언어를 바꾸면 다시 켜지 않아도 바로 바뀌고 기기에 저장한다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn();
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

  testWidgets('폭 320의 아래쪽 탭으로 화면을 바꾸고, 대국실과 기보는 로그인을 띄우며 내 정보는 로그인 없이 설정까지 간다', (tester) async {
    _useView(tester, const Size(320, 640));
    setUpFakeApp();
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    for (final label in ['홈', '대국실', '관전', '기보', '내 정보']) {
      expect(_inTabBar(label), findsOneWidget);
    }
    expect(find.byType(SideMenu), findsNothing);
    // 탭으로 옮긴 임시 버튼들이 없다.
    expect(find.text('전체 보기'), findsNothing);
    expect(find.widgetWithText(FilledButton, '대국실'), findsNothing);
    // 상점은 아직 누를 수 없다.
    final store = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.storefront_outlined));
    expect(store.onPressed, isNull);

    await _tap(tester, _inTabBar('관전'));
    expect(find.byType(SpectateListScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(AppTabBar), findsOneWidget);

    // 로그인 창을 닫으면 하던 화면에 그대로 머문다.
    await _tap(tester, _inTabBar('대국실'));
    expect(find.text('로그인하고\n대국실에 들어가 보세요'), findsOneWidget);
    await _tap(tester, find.byTooltip('닫기'));
    expect(find.byType(LobbyScreen), findsNothing);
    expect(find.byType(SpectateListScreen), findsOneWidget);

    await _tap(tester, _inTabBar('기보'));
    expect(find.text('로그인하면\n내 기보를 볼 수 있어요'), findsOneWidget);
    await _tap(tester, find.byTooltip('닫기'));
    expect(find.byType(RecordsScreen), findsNothing);

    await _tap(tester, _inTabBar('내 정보'));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(SpectateListScreen), findsNothing);
    expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
    expect(find.text('차단 목록'), findsNothing);
    expect(find.text('전적'), findsNothing);

    // 설정은 탭 화면이 아니라 뒤로 간다. 로그인 전에는 계정과 신청 받기를 두지 않는다.
    await _tap(tester, find.text('설정'));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('소리'), findsOneWidget);
    expect(find.text('대국 신청 받기'), findsNothing);
    expect(find.text('계정'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await _pumpFor(tester);

    await _tap(tester, _inTabBar('홈'));
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('내 정보의 로그인 버튼으로 로그인하면 그 자리에서 프로필과 전적이 보인다', (tester) async {
    _useView(tester, const Size(390, 844));
    final fakes = setUpFakeApp();
    fakes.users.profiles['google-user'] = UserProfile(
      nickname: '장기왕',
      rankLevel: 1,
      stats: const UserStats(games: 7, wins: 4, losses: 3),
      createdAt: DateTime.utc(2026, 11, 4),
    );
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    await _tap(tester, _inTabBar('내 정보'));
    await _tap(tester, find.widgetWithText(FilledButton, '로그인'));
    expect(find.text('로그인하면\n급수와 전적을 볼 수 있어요'), findsOneWidget);
    await _tap(tester, find.text('Google로 계속하기'));

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('장기왕'), findsOneWidget);
    expect(find.text('전적'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('차단 목록'), findsOneWidget);
  });

  testWidgets('폭 320에서 글자를 1.3배로 키워도 탭 줄과 설정이 넘치지 않는다', (tester) async {
    _useView(tester, const Size(320, 640), textScale: 1.3);
    final fakes = await _signIn();
    fakes.auth.signInMethod = SignInMethod.google;
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    expect(tester.takeException(), isNull);

    await _tap(tester, _inTabBar('내 정보'));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('설정'), 200, scrollable: find.byType(Scrollable).first);
    await _tap(tester, find.text('설정'));
    expect(find.text('Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('글자를 입력하는 동안에는 탭 줄을 숨긴다', (tester) async {
    _useView(tester, const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    setUpFakeApp();
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    expect(find.byType(AppTabBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('소리와 진동은 기기에 저장하고 앱을 켤 때 읽는다', (tester) async {
    _useView(tester, const Size(390, 844));
    final fakes = setUpFakeApp();
    expect(managers.effectSettingsManager.soundEnabled, isTrue);
    expect(managers.effectSettingsManager.vibrationEnabled, isTrue);
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    await _tap(tester, _inTabBar('내 정보'));
    await _tap(tester, find.text('설정'));

    await _tap(tester, find.text('소리'));
    await _tap(tester, find.text('진동'));
    expect(fakes.deviceSettings.soundEnabled, isFalse);
    expect(fakes.deviceSettings.vibrationEnabled, isFalse);

    await managers.effectSettingsManager.load();
    expect(managers.effectSettingsManager.soundEnabled, isFalse);
    expect(managers.effectSettingsManager.vibrationEnabled, isFalse);
  });

  testWidgets('설정의 대국 신청 받기, 로그인 방식, 정보를 보여주고 로그아웃하면 대국실 항목을 지우고 홈으로 간다', (tester) async {
    _useView(tester, const Size(390, 844));
    final fakes = await _signIn();
    fakes.auth.signInMethod = SignInMethod.email;
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    await _tap(tester, _inTabBar('내 정보'));
    await _tap(tester, find.text('설정'));

    // 대국실 항목이 없어도 `users_private`의 값으로 바꾼다.
    await _tap(tester, find.text('대국 신청 받기'));
    expect(fakes.userPrivates.challengesEnabledWrites, ['me false']);
    expect(find.text('이메일'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('버전'), 200, scrollable: find.byType(Scrollable).first);
    await _pumpFor(tester);
    expect(find.text('1.2.3'), findsOneWidget);
    expect(find.text('오픈소스 라이선스'), findsOneWidget);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, '이용약관')).enabled, isFalse);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, '개인정보처리방침')).enabled, isFalse);

    await tester.scrollUntilVisible(find.text('로그아웃'), -200, scrollable: find.byType(Scrollable).first);
    await _pumpFor(tester);
    await _tap(tester, find.text('로그아웃'));
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('로그아웃')));

    expect(managers.authManager.signedIn, isFalse);
    expect(fakes.onlineUsers.calls, contains('remove me'));
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('로그인하면 급수와 전적이 저장돼요'), findsOneWidget);
  });

  testWidgets('1024 이상은 탭 줄 대신 왼쪽 메뉴에 상점 자리와 설정을 둔다', (tester) async {
    _useView(tester, const Size(1024, 720));
    setUpFakeApp();
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(find.byType(AppTabBar), findsNothing);
    expect(_inSideMenu('상점'), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.storefront_outlined), findsNothing);

    // 상점은 아직 눌러도 아무 일이 없다.
    await _tap(tester, _inSideMenu('상점'));
    expect(find.byType(HomeScreen), findsOneWidget);

    await _tap(tester, _inSideMenu('설정'));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await _tap(tester, _inSideMenu('내 정보'));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    await _tap(tester, _inSideMenu('홈'));
    expect(find.byType(ProfileScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈의 관전 카드는 탭에서 돌아오면 다시 읽는다', (tester) async {
    _useView(tester, const Size(390, 844));
    final fakes = setUpFakeApp();
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    expect(fakes.spectateList.getEntriesCount, 1);

    await _tap(tester, _inTabBar('관전'));
    expect(fakes.spectateList.getEntriesCount, 2);
    await _tap(tester, _inTabBar('홈'));
    expect(fakes.spectateList.getEntriesCount, 3);
  });
}
