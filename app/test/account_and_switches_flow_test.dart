import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/config.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/app_config.dart';
import 'package:janggigo/models/player_state.dart';
import 'package:janggigo/models/user_private.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/email_login_screen.dart';
import 'package:janggigo/screens/lobby_screen.dart';
import 'package:janggigo/screens/login_flow.dart';
import 'package:janggigo/screens/login_sheet.dart';
import 'package:janggigo/screens/nickname_screen.dart';
import 'package:janggigo/screens/settings_screen.dart';
import 'package:janggigo/utils/app_exception.dart';
import 'package:janggigo/utils/app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fakes.dart';

void _useView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
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

PlayerState _playerState({
  String? gameId,
  String? roomId,
  DateTime? quickQueueJoinedAt,
  String? outgoingChallengeId,
  String? incomingChallengeId,
}) => PlayerState(
  roomId: roomId,
  gameId: gameId,
  lastGameId: null,
  outgoingChallengeId: outgoingChallengeId,
  incomingChallengeId: incomingChallengeId,
  setupDraft: null,
  lastRankChange: null,
  gamePracticeGameId: null,
  quickQueueJoinedAt: quickQueueJoinedAt,
  updatedAt: DateTime.utc(2026, 11, 6),
);

/// 앱을 띄우고 내 정보의 설정을 연다.
Future<void> _openSettings(WidgetTester tester) async {
  await tester.pumpWidget(const JanggigoApp());
  await _pumpFor(tester);
  await _tap(tester, find.text('내 정보').last);
  await _tap(tester, find.text('설정'));
}

const _deleteLabel = '회원 탈퇴';
const _confirmButton = '탈퇴하기';

Finder _inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

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

  group('회원 탈퇴', () {
    testWidgets('확인하면 방·대기열·신청에서 나오고 탈퇴한 뒤 로그아웃하고 홈으로 간다', (tester) async {
      _useView(tester);
      final fakes = await _signIn();
      await _openSettings(tester);
      fakes.playerStates.emit(
        'me',
        _playerState(
          roomId: 'r1',
          quickQueueJoinedAt: DateTime.utc(2026, 11, 6),
          outgoingChallengeId: 'c1',
          incomingChallengeId: 'c2',
        ),
      );
      await _pumpFor(tester);

      await _tap(tester, find.text(_deleteLabel));
      expect(find.textContaining('30일 뒤 모두 지우고'), findsOneWidget);
      expect(find.textContaining(supportEmail), findsOneWidget);
      await _tap(tester, _inDialog(_confirmButton));

      expect(fakes.auth.appleRevokeCalls, 1);
      expect(fakes.rooms.calls, contains('leaveRoom r1'));
      expect(fakes.games.calls, contains('leaveQuickQueue'));
      expect(fakes.challenges.calls, containsAll(['cancelChallenge c1', 'respondChallenge c2 false']));
      expect(fakes.users.deletedAccounts, ['me']);
      expect(managers.authManager.signedIn, isFalse);
      expect(fakes.onlineUsers.calls, contains('remove me'));

      expect(find.text('탈퇴했어요'), findsOneWidget);
      await _tap(tester, _inDialog('확인'));
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('로그인하면 급수와 전적이 저장돼요'), findsOneWidget);
    });

    testWidgets('진행 중인 대국이 있으면 묻지 않고 막는다', (tester) async {
      _useView(tester);
      final fakes = await _signIn();
      await _openSettings(tester);
      fakes.playerStates.emit('me', _playerState(gameId: 'g1'));
      await _pumpFor(tester);

      await _tap(tester, find.text(_deleteLabel));

      expect(find.text('대국 중에는 탈퇴할 수 없어요'), findsOneWidget);
      expect(find.text(_confirmButton), findsNothing);
      expect(fakes.users.deletedAccounts, isEmpty);
      expect(managers.authManager.signedIn, isTrue);

      // 대국 중 접속 확인 타이머를 끝낸다.
      fakes.playerStates.emit('me', _playerState());
      await _pumpFor(tester);
    });

    testWidgets('취소하면 아무것도 하지 않는다', (tester) async {
      _useView(tester);
      final fakes = await _signIn();
      await _openSettings(tester);

      await _tap(tester, find.text(_deleteLabel));
      await _tap(tester, _inDialog('취소'));

      expect(fakes.auth.appleRevokeCalls, 0);
      expect(fakes.users.deletedAccounts, isEmpty);
      expect(managers.authManager.signedIn, isTrue);
    });

    testWidgets('애플 로그인 창을 닫으면 조용히 멈춘다', (tester) async {
      _useView(tester);
      final fakes = await _signIn();
      await _openSettings(tester);
      fakes.auth.nextAppleRevokeError = const AppException(AppErrorCode.signInCanceled);

      await _tap(tester, find.text(_deleteLabel));
      await _tap(tester, _inDialog(_confirmButton));

      expect(find.byType(AlertDialog), findsNothing);
      expect(fakes.users.deletedAccounts, isEmpty);
      expect(managers.authManager.signedIn, isTrue);
    });

    testWidgets('서버가 거절하면 이유를 알리고 로그인을 둔다', (tester) async {
      _useView(tester);
      final fakes = await _signIn();
      await _openSettings(tester);
      fakes.users.nextDeleteAccountError = const AppException(AppErrorCode.accountInGame);

      await _tap(tester, find.text(_deleteLabel));
      await _tap(tester, _inDialog(_confirmButton));
      expect(find.text('대국 중에는 탈퇴할 수 없어요'), findsOneWidget);
      await _tap(tester, _inDialog('확인'));
      expect(managers.authManager.signedIn, isTrue);

      fakes.users.nextDeleteAccountError = Exception('unavailable');
      await _tap(tester, find.text(_deleteLabel));
      await _tap(tester, _inDialog(_confirmButton));
      expect(find.text('탈퇴하지 못했어요. 잠시 후 다시 해 주세요'), findsOneWidget);
      expect(managers.authManager.signedIn, isTrue);
    });

    test('다른 기기에서 탈퇴해 프로필이 없고 로그인이 무효면 닉네임 정하기로 보내지 않고 로그아웃한다', () async {
      final fakes = setUpFakeApp();
      fakes.auth.signInValid = false;

      await managers.authManager.signInWithEmail(email: 'me', password: 'password');

      expect(managers.authManager.signedIn, isFalse);
    });
  });

  group('로그인 창', () {
    testWidgets('만 14세 동의 문구를 보여준다', (tester) async {
      _useView(tester);
      setUpFakeApp();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);
      final context = tester.element(find.byType(Scaffold).first);

      unawaited(LoginSheet.show(context, LoginPurpose.home));
      await _pumpFor(tester);

      expect(find.textContaining('계속하면 만 14세 이상이며', findRichText: true), findsOneWidget);
    });

    testWidgets('탈퇴한 계정으로 로그인하면 되돌리는 방법을 알린다', (tester) async {
      _useView(tester);
      final fakes = setUpFakeApp();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(LoginSheet.show(context, LoginPurpose.home));
      await _pumpFor(tester);
      fakes.auth.nextSignInError = const AppException(AppErrorCode.accountDisabled);

      await _tap(tester, find.text('Google로 계속하기'));

      expect(find.text('탈퇴한 계정이에요. 되돌리려면 $supportEmail로 알려 주세요'), findsOneWidget);
    });
  });

  group('signupEnabled', () {
    testWidgets('끄면 프로필이 없는 사람은 알린 뒤 로그아웃하고 이메일 가입 링크를 숨긴다', (tester) async {
      _useView(tester);
      final fakes = setUpFakeApp();
      fakes.configs.signupEnabled = false;
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);
      final context = tester.element(find.byType(Scaffold).first);
      final results = <bool>[];
      unawaited(ensureSignedInWithProfile(context, LoginPurpose.quickMatch).then(results.add));
      await _pumpFor(tester);

      await _tap(tester, find.text('이메일로 계속하기'));
      expect(find.byType(EmailLoginScreen), findsOneWidget);
      expect(find.text('처음이신가요?'), findsNothing);
      await _tap(tester, find.byType(BackButton));

      await _tap(tester, find.text('Google로 계속하기'));
      expect(find.text('지금은 새로 가입할 수 없어요'), findsOneWidget);
      expect(find.byType(NicknameScreen), findsNothing);
      await _tap(tester, _inDialog('확인'));

      expect(results, [false]);
      expect(managers.authManager.signedIn, isFalse);
    });

    testWidgets('서버가 가입을 거절하면 알린 뒤 로그아웃하고 닉네임 화면을 닫는다', (tester) async {
      _useView(tester);
      final fakes = setUpFakeApp();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);
      final context = tester.element(find.byType(Scaffold).first);
      final results = <bool>[];
      unawaited(ensureSignedInWithProfile(context, LoginPurpose.quickMatch).then(results.add));
      await _pumpFor(tester);
      await _tap(tester, find.text('Google로 계속하기'));
      expect(find.byType(NicknameScreen), findsOneWidget);

      fakes.users.nextCreateProfileError = const AppException(AppErrorCode.signupBlocked);
      await tester.enterText(find.byType(TextField), '장기왕');
      await _pumpFor(tester);
      await _tap(tester, find.byType(FilledButton));

      expect(find.text('이 계정은 지금 다시 가입할 수 없어요'), findsOneWidget);
      await _tap(tester, _inDialog('확인'));

      expect(results, [false]);
      expect(managers.authManager.signedIn, isFalse);
      expect(find.byType(NicknameScreen), findsNothing);
    });
  });

  group('chatEnabled', () {
    testWidgets('끄면 대국실의 채팅 탭이 사라지고 켜면 돌아온다', (tester) async {
      _useView(tester);
      final fakes = await _signIn();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);
      unawaited(LobbyScreen.open(tester.element(find.byType(Scaffold).first)));
      await _pumpFor(tester);
      Finder chatTab() => find.descendant(of: find.byType(TabBar), matching: find.text('채팅'));
      expect(chatTab(), findsOneWidget);

      fakes.configs.chatEnabled = false;
      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(chatTab(), findsNothing);

      fakes.configs.chatEnabled = true;
      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(chatTab(), findsOneWidget);
    });
  });

  group('앱 전체를 막는 스위치', () {
    testWidgets('앱 버전이 minAppVersion보다 낮으면 업데이트 화면만 보여준다', (tester) async {
      _useView(tester);
      final fakes = setUpFakeApp();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);
      expect(find.text('새 버전으로 업데이트해 주세요'), findsNothing);

      fakes.configs.minAppVersion = '1.2.4';
      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(find.text('새 버전으로 업데이트해 주세요'), findsOneWidget);
      expect(find.text('업데이트'), findsOneWidget);
      expect(find.text('빠른 대국'), findsNothing);

      fakes.configs.minAppVersion = '1.2.3';
      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(find.text('새 버전으로 업데이트해 주세요'), findsNothing);
    });

    testWidgets('웹에서 webEnabled를 끄면 안내 화면만 보여주고 앱은 그대로다', (tester) async {
      _useView(tester);
      final fakes = setUpFakeApp();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);

      fakes.configs.webEnabled = false;
      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(find.text('지금은 웹에서 이용할 수 없어요. 앱을 이용해 주세요'), findsNothing);

      managers.appConfigManager.web = true;
      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(find.text('지금은 웹에서 이용할 수 없어요. 앱을 이용해 주세요'), findsOneWidget);
    });
  });

  group('공지', () {
    const notice = ServiceNotice(messageKo: '오늘 밤 점검합니다', messageEn: 'Maintenance tonight', gamesBlocked: true);

    testWidgets('한 번만 띄우고 문구가 바뀌면 다시 띄운다', (tester) async {
      _useView(tester);
      final fakes = setUpFakeApp();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);

      fakes.configs.serviceNotice = notice;
      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(find.text('오늘 밤 점검합니다'), findsOneWidget);
      await _tap(tester, _inDialog('확인'));

      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(find.text('오늘 밤 점검합니다'), findsNothing);

      fakes.configs.serviceNotice = const ServiceNotice(
        messageKo: '점검을 미룹니다',
        messageEn: 'Maintenance delayed',
        gamesBlocked: false,
      );
      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(find.text('점검을 미룹니다'), findsOneWidget);
    });

    testWidgets('대국 중이면 끝난 뒤 띄운다', (tester) async {
      _useView(tester);
      final fakes = await _signIn();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);
      fakes.playerStates.emit('me', _playerState(gameId: 'g1'));
      await _pumpFor(tester);

      fakes.configs.serviceNotice = notice;
      fakes.configs.emitConfig();
      await _pumpFor(tester);
      expect(find.text('오늘 밤 점검합니다'), findsNothing);

      fakes.playerStates.emit('me', _playerState());
      await _pumpFor(tester);
      expect(find.text('오늘 밤 점검합니다'), findsOneWidget);
    });

    testWidgets('한국어가 아니면 영어 문구를 띄운다', (tester) async {
      _useView(tester);
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      final fakes = setUpFakeApp();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);

      fakes.configs.serviceNotice = notice;
      fakes.configs.emitConfig();
      await _pumpFor(tester);

      expect(find.text('Maintenance tonight'), findsOneWidget);
    });
  });

  group('isOlderVersion', () {
    test('세 숫자를 앞에서부터 본다', () {
      expect(isOlderVersion('1.2.3', '1.2.4'), isTrue);
      expect(isOlderVersion('1.2.3', '1.3.0'), isTrue);
      expect(isOlderVersion('1.9.9', '2.0.0'), isTrue);
      expect(isOlderVersion('1.2.3', '1.2.3'), isFalse);
      expect(isOlderVersion('1.10.0', '1.9.0'), isFalse);
    });

    test('모양이 다르면 막지 않는다', () {
      expect(isOlderVersion('1.2', '1.2.4'), isFalse);
      expect(isOlderVersion('1.2.3', 'abc'), isFalse);
    });
  });
}
