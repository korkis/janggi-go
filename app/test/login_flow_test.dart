import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/config.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/l10n/app_localizations_ko.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/email_login_screen.dart';
import 'package:janggigo/screens/home_screen.dart';
import 'package:janggigo/screens/login_flow.dart';
import 'package:janggigo/screens/nickname_screen.dart';
import 'package:janggigo/theme/app_theme.dart';
import 'package:janggigo/utils/rank_format.dart';

import 'fakes.dart';

Widget _app(Widget home) => MaterialApp(
  theme: lightTheme,
  locale: const Locale('ko'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// 빠른 대국처럼 로그인이 필요한 버튼. 로그인 흐름이 끝나면 [results]에 결과를 남긴다.
class _NeedsLoginButton extends StatelessWidget {
  final List<bool> results;

  const _NeedsLoginButton(this.results);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(onPressed: () => _onPressed(context), child: const Text('빠른 대국')),
      ),
    );
  }

  Future<void> _onPressed(BuildContext context) async {
    results.add(await ensureSignedInWithProfile(context, LoginPurpose.quickMatch));
  }
}

void main() {
  final l10n = AppLocalizationsKo();

  testWidgets('홈의 로그인 버튼으로 Google 로그인과 닉네임 정하기를 거치면 내 카드에 닉네임과 급수가 보인다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    await tester.pumpWidget(_app(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text(l10n.homeLoginGuide), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l10n.login));
    await tester.pumpAndSettle();

    expect(find.text(l10n.loginSheetTitleHome), findsOneWidget);
    expect(find.text(l10n.loginWithGoogle), findsOneWidget);
    expect(find.text(l10n.loginWithApple), findsOneWidget);
    expect(find.text(l10n.loginWithEmail), findsOneWidget);

    await tester.tap(find.text(l10n.loginWithGoogle));
    await tester.pumpAndSettle();
    expect(fakes.auth.lastSignInMethod, 'google');
    expect(find.byType(NicknameScreen), findsOneWidget);
    // 홈에서 왔으면 이어서 할 일 안내가 없다.
    expect(find.text(l10n.nicknameStartHintQuickMatch), findsNothing);

    await tester.enterText(find.byType(TextField), '장기왕');
    await tester.pump(nicknameCheckDelay);
    await tester.pumpAndSettle();
    expect(find.text(l10n.nicknameAvailable), findsOneWidget);
    expect(find.text('3/10'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, l10n.nicknameStart));
    await tester.pumpAndSettle();

    expect(find.byType(NicknameScreen), findsNothing);
    expect(find.text('장기왕'), findsOneWidget);
    expect(find.text(l10n.rankKyu(18)), findsOneWidget);
    expect(fakes.users.profiles['google-user']?.nickname, '장기왕');
  });

  testWidgets('로그인과 닉네임 정하기가 끝나면 하려던 일을 이어서 하도록 true를 돌려준다', (tester) async {
    _usePhoneView(tester);
    setUpFakeApp();
    final results = <bool>[];
    await tester.pumpWidget(_app(_NeedsLoginButton(results)));

    await tester.tap(find.text('빠른 대국'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.loginSheetTitleQuickMatch), findsOneWidget);

    await tester.tap(find.text(l10n.loginWithApple));
    await tester.pumpAndSettle();
    expect(find.text(l10n.nicknameStartHintQuickMatch), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'King');
    await tester.pump(nicknameCheckDelay);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.nicknameStart));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  testWidgets('이미 프로필이 있으면 로그인 창 없이 바로 true를 돌려준다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.profiles['google-user'] = UserProfile(
      nickname: '장기왕',
      rankLevel: 1,
      stats: const UserStats(games: 0, wins: 0, losses: 0),
      createdAt: DateTime.utc(2026, 11, 2),
    );
    await fakes.auth.signInWithGoogle();
    final results = <bool>[];
    await tester.pumpWidget(_app(_NeedsLoginButton(results)));

    await tester.tap(find.text('빠른 대국'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.loginSheetTitleQuickMatch), findsNothing);
    expect(results, [true]);
  });

  testWidgets('로그인 창을 닫으면 하던 화면에 머물고 false를 돌려준다', (tester) async {
    _usePhoneView(tester);
    setUpFakeApp();
    final results = <bool>[];
    await tester.pumpWidget(_app(_NeedsLoginButton(results)));

    await tester.tap(find.text('빠른 대국'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.close));
    await tester.pumpAndSettle();

    expect(find.text(l10n.loginSheetTitleQuickMatch), findsNothing);
    expect(results, [false]);
    expect(managers.authManager.signedIn, isFalse);
  });

  testWidgets('닉네임 형식이 틀리거나 이미 쓰는 닉네임이면 시작하기를 누를 수 없다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.users.takenNicknames.add('king');
    await fakes.auth.signInWithGoogle();
    await tester.pumpWidget(_app(const NicknameScreen(purpose: LoginPurpose.home)));

    await tester.enterText(find.byType(TextField), '장');
    await tester.pump();
    expect(find.text(l10n.nicknameInvalidFormat), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'KING');
    await tester.pump(nicknameCheckDelay);
    await tester.pumpAndSettle();
    expect(find.text(l10n.nicknameTaken), findsOneWidget);

    final startButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, l10n.nicknameStart));
    expect(startButton.onPressed, isNull);
  });

  testWidgets('이메일 로그인은 입력을 검사하고, 맞으면 로그인한다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    final results = <bool>[];
    await tester.pumpWidget(_app(_NeedsLoginButton(results)));

    await tester.tap(find.text('빠른 대국'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.loginWithEmail));
    await tester.pumpAndSettle();
    expect(find.text(l10n.emailLoginTitle), findsOneWidget);

    // 디버그 빌드는 시험 계정을 미리 넣으므로 지우고 검사한다.
    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.tap(find.widgetWithText(FilledButton, l10n.login));
    await tester.pumpAndSettle();
    expect(find.text(l10n.errorInvalidEmail), findsOneWidget);
    expect(find.text(l10n.errorPasswordEmpty), findsOneWidget);
    expect(fakes.auth.lastSignInMethod, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'jangi@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    await tester.tap(find.widgetWithText(FilledButton, l10n.login));
    await tester.pumpAndSettle();

    expect(fakes.auth.lastSignInMethod, 'email');
    expect(find.byType(NicknameScreen), findsOneWidget);
  });

  testWidgets('디버그 빌드의 이메일 로그인은 시험 계정을 미리 넣고, 번호를 치고 Enter를 누르면 로그인한다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    final results = <bool>[];
    await tester.pumpWidget(_app(_NeedsLoginButton(results)));

    await tester.tap(find.text('빠른 대국'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.loginWithEmail));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(emailField.autofocus, isTrue);
    expect(emailField.controller!.text, 'test@janggigo.test');
    expect(emailField.controller!.selection, const TextSelection.collapsed(offset: 4));
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, 'janggigo1');

    await tester.enterText(find.byType(TextField).at(0), 'test1@janggigo.test');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(fakes.auth.lastSignInMethod, 'email');
    expect(fakes.auth.currentUid, 'test1@janggigo.test');
  });

  testWidgets('이메일 가입 화면에는 시험 계정을 넣지 않는다', (tester) async {
    _usePhoneView(tester);
    setUpFakeApp();
    await tester.pumpWidget(_app(const EmailLoginScreen(signUp: true)));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, isEmpty);
  });

  testWidgets('이메일 가입은 비밀번호 확인이 다르면 가입하지 않는다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    final results = <bool>[];
    await tester.pumpWidget(_app(_NeedsLoginButton(results)));

    await tester.tap(find.text('빠른 대국'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.loginWithEmail));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.emailSignUpTitle));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'new@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    await tester.enterText(find.byType(TextField).at(2), 'password2');
    await tester.tap(find.widgetWithText(FilledButton, l10n.signUp));
    await tester.pumpAndSettle();
    expect(find.text(l10n.errorPasswordMismatch), findsOneWidget);
    expect(fakes.auth.lastSignInMethod, isNull);

    await tester.enterText(find.byType(TextField).at(2), 'password1');
    await tester.tap(find.widgetWithText(FilledButton, l10n.signUp));
    await tester.pumpAndSettle();
    expect(fakes.auth.lastSignInMethod, 'emailSignUp');
    expect(find.byType(NicknameScreen), findsOneWidget);
  });

  test('rankLevel을 급수 글자로 바꾼다', () {
    expect(getRankLabel(l10n, 1), '18급');
    expect(getRankLabel(l10n, 18), '1급');
    expect(getRankLabel(l10n, 19), '1단');
    expect(getRankLabel(l10n, 27), '9단');
  });
}
