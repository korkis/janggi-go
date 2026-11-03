import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/chat_message.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/game_screen.dart';
import 'package:janggigo/screens/lobby_screen.dart';
import 'package:janggigo/theme/app_theme.dart';
import 'package:janggigo/utils/app_exception.dart';
import 'package:janggigo/widgets/chat_view.dart';
import 'package:janggigo/widgets/game_scaffold.dart';

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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _pumpFor(tester);
}

UserProfile _profile(String nickname) => UserProfile(
  nickname: nickname,
  rankLevel: 1,
  stats: const UserStats(games: 0, wins: 0, losses: 0),
  createdAt: DateTime.utc(2026, 11, 3),
);

Future<FakeApp> _signIn(String uid, String nickname) async {
  final fakes = setUpFakeApp();
  fakes.users.profiles[uid] = _profile(nickname);
  await fakes.auth.signInWithEmail(email: uid, password: 'password');
  await managers.authManager.ensureProfileLoaded();
  return fakes;
}

Widget _app(Widget home, {ThemeData? theme}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: theme == null ? home : Theme(data: theme, child: home),
  );
}

void main() {
  testWidgets('대국실 채팅에서 보내고, 걸린 메시지는 가운데 안내로 알리고, 길게 눌러 신고·차단한다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    final otherMessage = fakes.chats.addMessage(ChatChannel.lobby, null, uid: 'other', nickname: '장기왕', text: '반가워요');
    await tester.pumpWidget(_app(const LobbyScreen()));
    await _pumpFor(tester);

    await _tap(tester, find.text('채팅'));
    // 처음 연 채팅 창에 한 번 안내한다.
    expect(find.text('메시지를 길게 누르면 신고·차단할 수 있어요'), findsOneWidget);
    expect(find.text('장기왕'), findsOneWidget);
    expect(find.text('반가워요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  잘 부탁합니다 ');
    await _tap(tester, find.byTooltip('보내기'));
    expect(fakes.chats.calls, ['send lobby - 잘 부탁합니다']);
    expect(find.text('  잘 부탁합니다 '), findsNothing);
    // 서버가 저장하면 내 메시지는 닉네임 없이 오른쪽에 보인다.
    fakes.chats.addMessage(ChatChannel.lobby, null, uid: 'me', nickname: '나', text: '잘 부탁합니다');
    await _pumpFor(tester);
    expect(find.text('잘 부탁합니다'), findsOneWidget);
    expect(find.text('나'), findsNothing);
    expect(tester.getTopRight(find.text('잘 부탁합니다')).dx, greaterThan(tester.getTopRight(find.text('반가워요')).dx));

    // 자주 쓰는 말은 누르면 바로 보낸다.
    await _tap(tester, find.text('반갑습니다'));
    expect(fakes.chats.calls.last, 'send lobby - 반갑습니다');

    // 검사에 걸리면 입력을 남기고 가운데 회색 안내로 알린다.
    fakes.chats.nextError = const AppException(AppErrorCode.chatMessageBlocked);
    await tester.enterText(find.byType(TextField), '나쁜 말');
    await _tap(tester, find.byTooltip('보내기'));
    expect(find.text('부적절한 표현이 있어 보내지 않았어요'), findsOneWidget);
    expect(find.text('나쁜 말'), findsOneWidget);

    // 그냥 누르면 아무 일도 하지 않는다.
    await _tap(tester, find.text('반가워요'));
    expect(find.text('신고하기'), findsNothing);

    await tester.longPress(find.text('반가워요'));
    await _pumpFor(tester);
    await _tap(tester, find.text('신고하기'));
    expect(fakes.chats.calls.last, 'report lobby - $otherMessage');
    expect(find.text('신고했어요. 운영진이 확인할게요'), findsOneWidget);

    // 내 메시지는 길게 눌러도 메뉴가 없다.
    await tester.longPress(find.text('잘 부탁합니다'));
    await _pumpFor(tester);
    expect(find.text('신고하기'), findsNothing);

    await tester.longPress(find.text('반가워요'));
    await _pumpFor(tester);
    await _tap(tester, find.text('차단하기'));
    expect(find.text('장기왕님을 차단할까요? 이 사람의 메시지와 대국 신청이 보이지 않아요'), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, '차단하기'));
    expect(fakes.blocks.writes, ['me other']);
    expect(find.text('반가워요'), findsNothing);
    expect(find.text('장기왕님을 차단했어요'), findsOneWidget);
  });

  testWidgets('대국 채팅은 새 메시지 수를 버튼에 보여주고, 상대 채팅을 끌 수 있고, 끝나면 결과 창에서 관전 채팅도 본다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    fakes.chats.addMessage(ChatChannel.game, 'g1', uid: 'opp', nickname: '한opp', text: '안녕하세요');
    await tester.pumpWidget(_app(const GameScreen.online(gameId: 'g1'), theme: gameTheme));
    fakes.games.emit(
      'g1',
      buildGameJson(
        phase: 'playing',
        hanFormation: 'horseElephantHorseElephant',
        choFormation: 'horseElephantHorseElephant',
        turn: 'cho',
        turnStartedAt: 1000000,
      ),
    );
    await _pumpFor(tester);

    GameBarButton chatButton() => tester.widget<GameBarButton>(find.widgetWithText(GameBarButton, '채팅'));
    // 화면을 열기 전의 메시지는 새 메시지로 세지 않는다.
    expect(chatButton().badgeCount, 0);
    fakes.chats.addMessage(ChatChannel.game, 'g1', uid: 'opp', nickname: '한opp', text: '빠르시네요');
    fakes.chats.addMessage(ChatChannel.game, 'g1', uid: 'opp', nickname: '한opp', text: '잘 두시네요');
    await _pumpFor(tester);
    expect(chatButton().badgeCount, 2);

    await _tap(tester, find.widgetWithText(GameBarButton, '채팅'));
    expect(find.text('빠르시네요'), findsOneWidget);
    expect(chatButton().badgeCount, 0);
    await _tap(tester, find.text('잘 부탁드립니다'));
    expect(fakes.chats.calls, ['send game g1 잘 부탁드립니다']);

    await _tap(tester, find.text('상대 채팅 끄기'));
    expect(find.text('빠르시네요'), findsNothing);
    fakes.chats.addMessage(ChatChannel.game, 'g1', uid: 'opp', nickname: '한opp', text: '또 봐요');
    await _pumpFor(tester);
    expect(find.text('또 봐요'), findsNothing);
    await _tap(tester, find.text('상대 채팅 켜기'));
    expect(find.text('또 봐요'), findsOneWidget);

    // 대국 중 대국자에게는 관전 채팅을 보여주지 않는다.
    expect(find.text('관전 채팅'), findsNothing);
    await tester.tapAt(const Offset(20, 20));
    await _pumpFor(tester);

    fakes.chats.addMessage(ChatChannel.spectator, 'g1', uid: 'viewer', nickname: '구경꾼', text: '좋은 대국이었어요');
    fakes.games.emit(
      'g1',
      buildGameJson(
        phase: 'finished',
        hanFormation: 'horseElephantHorseElephant',
        choFormation: 'horseElephantHorseElephant',
        turnStartedAt: 1000000,
        result: {'winner': 'cho', 'reason': 'resignation', 'choScore': 72, 'hanScore': 73.5},
        endedAt: 1040000,
      ),
    );
    await _pumpFor(tester);
    expect(find.text('초 승리!'), findsOneWidget);

    // 결과 창을 닫지 않고 채팅을 연다. 끝난 뒤에는 관전 채팅도 고를 수 있다.
    await _tap(tester, find.byType(ChatTextButton));
    expect(find.text('대국 채팅'), findsOneWidget);
    await _tap(tester, find.text('관전 채팅'));
    expect(find.text('좋은 대국이었어요'), findsOneWidget);
    await _tap(tester, find.text('좋은 수네요'));
    expect(fakes.chats.calls.last, 'send spectator g1 좋은 수네요');
  });

  testWidgets('차단 목록에서 닉네임과 날짜를 보고 차단을 푼다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    fakes.users.profiles['bad'] = _profile('악당');
    await fakes.blocks.createBlock('me', 'bad');
    await fakes.blocks.createBlock('me', 'gone');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    await _tap(tester, find.text('차단 목록'));
    expect(find.text('차단한 사람의 채팅 메시지와 대국 신청은 보이지 않아요'), findsOneWidget);
    expect(find.text('악당'), findsOneWidget);
    // 프로필을 찾지 못한 사람.
    expect(find.text('알 수 없는 사용자'), findsOneWidget);
    expect(find.textContaining('차단'), findsWidgets);
    // 최근에 차단한 사람이 위에 있다.
    expect(tester.getTopLeft(find.text('알 수 없는 사용자')).dy, lessThan(tester.getTopLeft(find.text('악당')).dy));

    await _tap(tester, find.widgetWithText(OutlinedButton, '차단 풀기').last);
    expect(fakes.blocks.writes.last, 'delete me bad');
    expect(find.text('악당'), findsNothing);
    expect(managers.blockManager.isBlocked('bad'), false);

    await _tap(tester, find.widgetWithText(OutlinedButton, '차단 풀기'));
    expect(find.text('차단한 사람이 없어요'), findsOneWidget);
  });
}
