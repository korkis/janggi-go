import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/user_private.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/lobby_screen.dart';
import 'package:janggigo/utils/app_exception.dart';

import 'fakes.dart';

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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _pumpFor(tester);
}

UserPrivate _userPrivate(ActiveSanction? sanction) => UserPrivate(
  challengesEnabled: true,
  rankProgress: 0,
  winsToNextRank: null,
  nicknameChangeCount: 0,
  nicknameChangedAt: null,
  sanction: sanction,
);

Future<FakeApp> _signIn() async {
  final fakes = setUpFakeApp();
  fakes.users.profiles['me'] = UserProfile(
    nickname: '나',
    rankLevel: 1,
    stats: const UserStats(games: 0, wins: 0, losses: 0),
    createdAt: DateTime.utc(2026, 11, 3),
  );
  await fakes.auth.signInWithEmail(email: 'me', password: 'password');
  await managers.authManager.ensureProfileLoaded();
  return fakes;
}

void main() {
  testWidgets('앱을 쓰는 중에 채팅 제한이 걸리면 사유, 끝나는 때, 이의 제기 이메일을 팝업으로 한 번 알린다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn();
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    expect(find.text('채팅이 제한되었어요'), findsNothing);

    final endsAt = DateTime.now().add(const Duration(days: 7));
    fakes.userPrivates.emit(
      'me',
      _userPrivate(ActiveSanction(type: SanctionType.chatRestriction, endsAt: endsAt, reason: '상대에게 욕설')),
    );
    await _pumpFor(tester);

    expect(find.text('채팅이 제한되었어요'), findsOneWidget);
    expect(find.text('제한이 끝날 때까지 채팅을 할 수 없어요'), findsOneWidget);
    expect(find.text('사유: 상대에게 욕설'), findsOneWidget);
    expect(find.textContaining('끝나는 때: '), findsOneWidget);
    expect(find.text('이의가 있으면 playkorkis@gmail.com로 메일을 보내 주세요'), findsOneWidget);

    await _tap(tester, find.text('확인'));
    expect(find.text('채팅이 제한되었어요'), findsNothing);
    // 기간이 있는 제재는 앱이 지우지 않는다.
    expect(fakes.userPrivates.clearWarningWrites, isEmpty);

    // 같은 제재로 다시 바뀌어도 이번 실행에서는 다시 띄우지 않는다.
    fakes.userPrivates.emit(
      'me',
      _userPrivate(ActiveSanction(type: SanctionType.chatRestriction, endsAt: endsAt, reason: '상대에게 욕설')),
    );
    await _pumpFor(tester);
    expect(find.text('채팅이 제한되었어요'), findsNothing);
  });

  testWidgets('경고는 확인을 누르면 지운다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn();
    fakes.userPrivates.emit(
      'me',
      _userPrivate(const ActiveSanction(type: SanctionType.warning, endsAt: null, reason: '반복된 비매너')),
    );
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(find.text('경고를 받았어요'), findsOneWidget);
    expect(find.text('사유: 반복된 비매너'), findsOneWidget);
    expect(find.textContaining('끝나는 때: '), findsNothing);

    await _tap(tester, find.text('확인'));
    expect(fakes.userPrivates.clearWarningWrites, ['me']);
  });

  testWidgets('끝난 제재와 모르는 종류의 제재', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn();
    fakes.userPrivates.emit(
      'me',
      _userPrivate(
        ActiveSanction(
          type: SanctionType.suspension,
          endsAt: DateTime.now().subtract(const Duration(minutes: 1)),
          reason: '끝남',
        ),
      ),
    );
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    // 예약 작업이 지우기 전이어도 끝난 제재는 알리지 않는다.
    expect(find.text('사유: 끝남'), findsNothing);

    fakes.userPrivates.emit('me', _userPrivate(const ActiveSanction(type: null, endsAt: null, reason: '새 제재')));
    await _pumpFor(tester);
    expect(find.text('이용이 제한되었어요'), findsOneWidget);
    expect(find.text('사유: 새 제재'), findsOneWidget);
  });

  testWidgets('채팅이 제한으로 거절되면 안내와 함께 제재 팝업을 다시 띄운다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LobbyScreen(),
      ),
    );
    await _pumpFor(tester);
    fakes.userPrivates.emit(
      'me',
      _userPrivate(
        ActiveSanction(
          type: SanctionType.chatRestriction,
          endsAt: DateTime.now().add(const Duration(days: 1)),
          reason: '욕설',
        ),
      ),
    );
    await _pumpFor(tester);

    await _tap(tester, find.text('채팅'));
    fakes.chats.nextError = const AppException(AppErrorCode.chatRestricted);
    await tester.enterText(find.byType(TextField), '안녕하세요');
    await _tap(tester, find.byTooltip('보내기'));

    expect(find.text('이용이 제한되어 지금은 채팅할 수 없어요'), findsOneWidget);
    expect(find.text('채팅이 제한되었어요'), findsOneWidget);
    expect(find.text('사유: 욕설'), findsOneWidget);
  });
}
