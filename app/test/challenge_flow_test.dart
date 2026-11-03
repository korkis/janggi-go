import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/active_game.dart';
import 'package:janggigo/models/challenge.dart';
import 'package:janggigo/models/game_enums.dart';
import 'package:janggigo/models/online_user.dart';
import 'package:janggigo/models/player_state.dart';
import 'package:janggigo/models/room.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/utils/app_exception.dart';

import 'fakes.dart';
import 'online_game_fixtures.dart';

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

/// 응답 시간 막대의 타이머가 있어 `pumpAndSettle` 대신 시간을 정해 흘린다.
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

PlayerState _playerState({String? roomId, String? gameId, String? incomingChallengeId, DateTime? queuedAt}) {
  return PlayerState(
    roomId: roomId,
    gameId: gameId,
    lastGameId: null,
    outgoingChallengeId: null,
    incomingChallengeId: incomingChallengeId,
    setupDraft: null,
    lastRankChange: null,
    quickQueueJoinedAt: queuedAt,
    updatedAt: DateTime.utc(2026, 11, 3),
  );
}

OnlineUser _onlineUser(
  String nickname, {
  int rankLevel = 1,
  OnlineStatus status = OnlineStatus.waiting,
  bool challengesEnabled = true,
}) {
  return OnlineUser(
    nickname: nickname,
    rankLevel: rankLevel,
    status: status,
    challengesEnabled: challengesEnabled,
    since: 0,
  );
}

Challenge _challenge({
  String fromUid = 'opp',
  String toUid = 'me',
  ChallengeStatus status = ChallengeStatus.pending,
  SideChoice? senderSide = SideChoice.cho,
  RoomHandicap? handicap,
  String? roomId,
  String? gameId,
}) {
  final now = DateTime.now().toUtc();
  return Challenge(
    fromUid: fromUid,
    from: const RoomPlayer(nickname: '상대', rankLevel: 19),
    toUid: toUid,
    roomId: roomId,
    senderSide: senderSide,
    handicap: handicap,
    timeControl: const TimeControl(
      baseMs: 600000,
      periodMs: 30000,
      periods: 3,
      setupMs: 20000,
      extensionPeriods: 2,
      extensionLimit: 2,
    ),
    status: status,
    gameId: gameId,
    expiresAt: now.add(const Duration(seconds: 20)),
    createdAt: now,
  );
}

/// [uid]로 로그인한 채 홈을 띄운다. [onlineUsersVisible]이면 대국실에 접속자 탭이 있다.
Future<FakeApp> _startSignedIn(WidgetTester tester, String uid, {bool onlineUsersVisible = true}) async {
  _usePhoneView(tester);
  final fakes = setUpFakeApp();
  fakes.configs.onlineUsersVisible = onlineUsersVisible;
  fakes.users.profiles[uid] = UserProfile(
    nickname: '나',
    rankLevel: 1,
    stats: const UserStats(games: 0, wins: 0, losses: 0),
    createdAt: DateTime.utc(2026, 11, 3),
  );
  fakes.onlineUsers.enteringUid = uid;
  fakes.onlineUsers.entryOnEnter = _onlineUser('나');
  await fakes.auth.signInWithEmail(email: uid, password: 'password');
  await tester.pumpWidget(const JanggigoApp());
  await _pumpFor(tester);
  return fakes;
}

Future<void> _tearDown(WidgetTester tester, FakeApp fakes, String uid) async {
  fakes.playerStates.emit(uid, null);
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('로그인하면 대국실에 들어가고, 다른 앱으로 넘어가면 나오고, 항목이 지워지면 다시 들어간다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    managers.connectionManager.observeAppLifecycle();
    expect(fakes.onlineUsers.calls, ['onDisconnect me', 'enterLobby']);

    // 지난 연결의 onDisconnect가 늦게 실행돼 항목이 지워졌다.
    fakes.onlineUsers.emitEntry('me', null);
    await _pumpFor(tester);
    expect(fakes.onlineUsers.calls, ['onDisconnect me', 'enterLobby', 'onDisconnect me', 'enterLobby']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await _pumpFor(tester);
    expect(fakes.onlineUsers.calls.last, 'remove me');
    final callsAfterLeave = fakes.onlineUsers.calls.length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFor(tester);
    expect(fakes.onlineUsers.calls.sublist(callsAfterLeave), ['onDisconnect me', 'enterLobby']);

    // RTDB 연결이 끊기면 서버가 걸어 둔 onDisconnect로 지우므로 앱은 쓰지 않고, 다시 연결되면 들어간다.
    fakes.connections.setConnected(false);
    await _pumpFor(tester);
    expect(fakes.onlineUsers.calls.length, callsAfterLeave + 2);
    fakes.connections.setConnected(true);
    await _pumpFor(tester);
    expect(fakes.onlineUsers.calls.sublist(callsAfterLeave + 2), ['onDisconnect me', 'enterLobby']);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('1024 이상에서는 접속자를 2열로 놓고 신청 보내기 창을 가운데 카드로 띄운다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    fakes.onlineUsers.emitUsers({'a': _onlineUser('가'), 'b': _onlineUser('나나'), 'c': _onlineUser('다')});
    await _pumpFor(tester);
    await _tap(tester, find.text('대국실'));
    await _tap(tester, find.text('접속자'));
    expect(tester.getTopLeft(find.text('가 · 18급')).dy, tester.getTopLeft(find.text('나나 · 18급')).dy);
    expect(tester.getTopLeft(find.text('다 · 18급')).dy, greaterThan(tester.getTopLeft(find.text('가 · 18급')).dy));

    await _tap(tester, find.widgetWithText(FilledButton, '신청').first);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('신청 보내기'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('로비 노출이 꺼져 있으면 대국실에 접속자 탭이 없다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me', onlineUsersVisible: false);
    await _tap(tester, find.text('대국실'));
    expect(find.text('방 목록'), findsOneWidget);
    expect(find.text('접속자'), findsNothing);
    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('접속자 탭은 나와 차단한 사람을 빼고 기다리는 사람을 위로 올리며 닉네임으로 찾는다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    await fakes.blocks.createBlock('me', 'blocked');
    fakes.onlineUsers.emitUsers({
      'me': _onlineUser('나'),
      'playing': _onlineUser('대국자', status: OnlineStatus.playing),
      'closed': _onlineUser('안받음', challengesEnabled: false),
      'waiting': _onlineUser('기다림', rankLevel: 19),
      'blocked': _onlineUser('차단됨'),
    });
    await _tap(tester, find.text('대국실'));
    await _tap(tester, find.text('접속자'));

    expect(find.text('접속자 3명'), findsOneWidget);
    expect(find.text('차단됨 · 18급'), findsNothing);
    final waitingY = tester.getTopLeft(find.text('기다림 · 1단')).dy;
    final closedY = tester.getTopLeft(find.text('안받음 · 18급')).dy;
    final playingY = tester.getTopLeft(find.text('대국자 · 18급')).dy;
    expect(waitingY, lessThan(closedY));
    expect(closedY, lessThan(playingY));
    expect(find.text('기다리는 중'), findsOneWidget);
    expect(find.text('신청 받지 않음'), findsOneWidget);
    expect(find.text('대국 중'), findsOneWidget);
    // 기다리는 사람에게만 신청 버튼이 있다.
    expect(find.widgetWithText(FilledButton, '신청'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '안받');
    await _pumpFor(tester);
    expect(find.text('안받음 · 18급'), findsOneWidget);
    expect(find.text('기다림 · 1단'), findsNothing);
    await tester.enterText(find.byType(TextField), '없는사람');
    await _pumpFor(tester);
    expect(find.text('찾는 닉네임이 없어요'), findsOneWidget);

    // 신청 받기 스위치는 설정과 내 항목을 함께 바꾼다.
    await _tap(tester, find.byType(Switch));
    expect(fakes.userPrivates.challengesEnabledWrites, ['me false']);
    expect(fakes.onlineUsers.calls.last, 'challengesEnabled me false');

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('신청을 보내고 상대가 수락하면 상차림으로 간다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.onlineUsers.emitUsers({'opp': _onlineUser('상대', rankLevel: 19)});
    await _tap(tester, find.text('대국실'));
    await _tap(tester, find.text('접속자'));

    await _tap(tester, find.widgetWithText(FilledButton, '신청'));
    expect(find.text('대국 신청'), findsOneWidget);
    expect(find.text('상대 · 1단'), findsWidgets);
    await _tap(tester, find.text('한'));
    await _tap(tester, find.text('신청 보내기'));
    expect(fakes.challenges.calls, ['sendChallenge opp han null null']);

    fakes.challenges.emit('challenge1', _challenge(fromUid: 'me', toUid: 'opp', senderSide: SideChoice.han));
    await _pumpFor(tester);
    expect(find.text('상대의 응답을 기다리고 있어요'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    fakes.games.emit('g1', buildGameJson(cho: 'opp', han: 'me', mode: 'challenge'));
    fakes.playerStates.emit('me', _playerState(gameId: 'g1'));
    fakes.challenges.emit(
      'challenge1',
      _challenge(fromUid: 'me', toUid: 'opp', status: ChallengeStatus.accepted, gameId: 'g1'),
    );
    await _pumpFor(tester);
    expect(find.text('상차림을 골라 주세요'), findsOneWidget);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('접장기 신청을 보내고 거절되면 알리고, 기다리는 동안 취소할 수 있다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.onlineUsers.emitUsers({'opp': _onlineUser('상대')});
    await _tap(tester, find.text('대국실'));
    await _tap(tester, find.text('접속자'));

    await _tap(tester, find.widgetWithText(FilledButton, '신청'));
    await _tap(tester, find.text('접장기'));
    expect(find.text('떼는 쪽이 한을 잡아요'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '신청 보내기')).onPressed, isNull);
    await _tap(tester, find.bySemanticsLabel('왼쪽 차'));
    await _tap(tester, find.text('신청 보내기'));
    expect(fakes.challenges.calls, ['sendChallenge opp null creator leftChariot']);
    fakes.challenges.emit('challenge1', _challenge(fromUid: 'me', toUid: 'opp'));
    await _pumpFor(tester);

    fakes.challenges.emit('challenge1', _challenge(fromUid: 'me', toUid: 'opp', status: ChallengeStatus.declined));
    await _pumpFor(tester);
    expect(find.text('상대가 신청을 거절했어요'), findsOneWidget);
    await _tap(tester, find.text('닫기'));
    expect(find.text('상대가 신청을 거절했어요'), findsNothing);

    // 다시 보내고 기다리는 동안 취소한다.
    fakes.challenges.sentChallengeId = 'challenge2';
    await _tap(tester, find.widgetWithText(FilledButton, '신청'));
    await _tap(tester, find.text('신청 보내기'));
    fakes.challenges.emit('challenge2', _challenge(fromUid: 'me', toUid: 'opp'));
    await _pumpFor(tester);
    await _tap(tester, find.text('신청 취소'));
    expect(fakes.challenges.calls.last, 'cancelChallenge challenge2');
    expect(find.text('상대의 응답을 기다리고 있어요'), findsNothing);

    // 서버가 거절한 이유를 알린다.
    fakes.challenges.nextError = const AppException(AppErrorCode.challengeLimited);
    await _tap(tester, find.widgetWithText(FilledButton, '신청'));
    await _tap(tester, find.text('신청 보내기'));
    expect(find.text('이 상대에게 여러 번 거절되어 잠시 신청할 수 없어요'), findsOneWidget);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('다른 사용자 정보에서 차단하면 한 번 묻고 접속자 목록에서 사라진다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.onlineUsers.emitUsers({'opp': _onlineUser('상대', status: OnlineStatus.playing)});
    await _tap(tester, find.text('대국실'));
    await _tap(tester, find.text('접속자'));

    await _tap(tester, find.text('상대 · 18급'));
    expect(find.text('상대'), findsOneWidget);
    // 대국 중인 사람에게는 신청할 수 없다.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '대국 신청')).onPressed, isNull);
    await _tap(tester, find.text('차단'));
    expect(find.text('상대님을 차단할까요? 이 사람의 메시지와 대국 신청이 보이지 않아요'), findsOneWidget);
    await _tap(tester, find.text('차단하기'));
    expect(fakes.blocks.writes, ['me opp']);
    expect(find.text('상대님을 차단했어요'), findsOneWidget);
    expect(find.text('상대 · 18급'), findsNothing);
    expect(find.text('지금 접속한 사람이 없어요'), findsOneWidget);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('신청을 받으면 어느 화면에서든 팝업을 띄우고, 수락하면 상차림으로 간다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    await _tap(tester, find.text('대국실'));

    fakes.challenges.emit('c1', _challenge(senderSide: SideChoice.cho));
    fakes.playerStates.emit('me', _playerState(incomingChallengeId: 'c1'));
    await _pumpFor(tester);
    expect(find.text('대국 신청이 왔어요'), findsOneWidget);
    expect(find.text('상대 · 1단'), findsOneWidget);
    expect(find.text('나는 한'), findsOneWidget);
    expect(find.text('기본 10분 · 초읽기 30초 3회'), findsOneWidget);

    fakes.challenges.respondResult = (gameId: 'g1', roomId: null);
    await _tap(tester, find.text('수락'));
    expect(fakes.challenges.calls, ['respondChallenge c1 true']);
    fakes.games.emit('g1', buildGameJson(cho: 'opp', han: 'me', mode: 'challenge'));
    fakes.playerStates.emit('me', _playerState(gameId: 'g1'));
    await _pumpFor(tester);
    expect(find.text('상차림을 골라 주세요'), findsOneWidget);
    // 대국실은 닫고 처음 화면 위에 상차림을 연다.
    expect(find.text('대국실', skipOffstage: false), findsOneWidget);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('받은 접장기 신청을 거절하고, 응답 시간이 지나면 팝업을 닫는다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');

    fakes.challenges.emit(
      'c1',
      _challenge(
        senderSide: null,
        handicap: const RoomHandicap(remover: HandicapRemover.creator, pieces: [HandicapPiece.leftChariot]),
      ),
    );
    fakes.playerStates.emit('me', _playerState(incomingChallengeId: 'c1'));
    await _pumpFor(tester);
    expect(find.text('접장기'), findsOneWidget);
    expect(find.text('상대가 떼요'), findsOneWidget);
    expect(find.text('나는 초'), findsOneWidget);
    await _tap(tester, find.text('거절'));
    expect(fakes.challenges.calls, ['respondChallenge c1 false']);
    fakes.playerStates.emit('me', _playerState());
    await _pumpFor(tester);

    // 다음 신청은 응답하지 않아 서버가 표시를 지운다.
    fakes.challenges.emit('c2', _challenge());
    fakes.playerStates.emit('me', _playerState(incomingChallengeId: 'c2'));
    await _pumpFor(tester);
    expect(find.text('대국 신청이 왔어요'), findsOneWidget);
    fakes.playerStates.emit('me', _playerState());
    await _pumpFor(tester);
    expect(find.text('대국 신청이 왔어요'), findsNothing);
    expect(fakes.challenges.calls, ['respondChallenge c1 false']);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('빠른 대국을 기다리다 받은 신청을 수락하면 대기 화면을 닫고 그 대국으로 간다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    await _tap(tester, find.text('빠른 대국'));
    expect(find.text('상대를 찾고 있어요'), findsOneWidget);

    fakes.challenges.emit('c1', _challenge());
    fakes.playerStates.emit('me', _playerState(incomingChallengeId: 'c1', queuedAt: DateTime.utc(2026, 11, 3)));
    await _pumpFor(tester);
    fakes.challenges.respondResult = (gameId: 'g1', roomId: null);
    await _tap(tester, find.text('수락'));
    fakes.games.emit('g1', buildGameJson(cho: 'me', han: 'opp', mode: 'challenge'));
    fakes.playerStates.emit('me', _playerState(gameId: 'g1'));
    await _pumpFor(tester);
    expect(find.text('상차림을 골라 주세요'), findsOneWidget);
    expect(find.text('상대를 찾고 있어요'), findsNothing);
    expect(fakes.games.calls, ['joinQuickQueue']);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('끝난 신청을 수락하면 알린다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.challenges.emit('c1', _challenge());
    fakes.playerStates.emit('me', _playerState(incomingChallengeId: 'c1'));
    await _pumpFor(tester);
    fakes.challenges.nextError = const AppException(AppErrorCode.gameNotFound);
    await _tap(tester, find.text('수락'));
    expect(find.text('이미 끝난 신청이에요'), findsOneWidget);
    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('방장은 접속자를 방에 초대하고, 초대받은 사람은 수락하면 방 대기실로 간다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    final room = Room(
      hostUid: 'me',
      host: const RoomPlayer(nickname: '나', rankLevel: 1),
      guestUid: null,
      guest: null,
      status: RoomStatus.waiting,
      listed: false,
      hostSide: SideChoice.cho,
      handicap: null,
      rankRange: null,
      gameId: null,
      kickedUids: const [],
      hostAbsentSince: null,
      guestAbsentSince: null,
      createdAt: DateTime.utc(2026, 11, 3),
      updatedAt: DateTime.utc(2026, 11, 3),
    );
    fakes.rooms.emit('room1', room);
    fakes.playerStates.emit('me', _playerState(roomId: 'room1'));
    fakes.onlineUsers.emitUsers({'opp': _onlineUser('상대'), 'busy': _onlineUser('바쁨', status: OnlineStatus.playing)});
    await _pumpFor(tester);
    await _tap(tester, find.text('방으로 돌아가기'));
    await _tap(tester, find.widgetWithText(FilledButton, '접속자 초대하기'));
    // 대국 중인 사람은 고를 수 없다.
    expect(find.widgetWithText(FilledButton, '초대'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, '초대'));
    expect(find.text('상대님을 이 방에 초대해요'), findsOneWidget);
    await _tap(tester, find.text('초대 보내기'));
    expect(fakes.challenges.calls, ['sendRoomInvite opp room1']);

    fakes.challenges.emit('challenge1', _challenge(fromUid: 'me', toUid: 'opp', roomId: 'room1'));
    await _pumpFor(tester);
    expect(find.text('상대의 응답을 기다리고 있어요'), findsOneWidget);
    fakes.challenges.emit(
      'challenge1',
      _challenge(fromUid: 'me', toUid: 'opp', roomId: 'room1', status: ChallengeStatus.accepted),
    );
    await _pumpFor(tester);
    expect(find.text('상대의 응답을 기다리고 있어요'), findsNothing);
    expect(find.text('나의 방'), findsOneWidget);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('방 초대를 수락하면 방 대기실로 간다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.rooms.emit(
      'room1',
      Room(
        hostUid: 'opp',
        host: const RoomPlayer(nickname: '상대', rankLevel: 19),
        guestUid: 'me',
        guest: const RoomPlayer(nickname: '나', rankLevel: 1),
        status: RoomStatus.waiting,
        listed: false,
        hostSide: SideChoice.cho,
        handicap: null,
        rankRange: null,
        gameId: null,
        kickedUids: const [],
        hostAbsentSince: null,
        guestAbsentSince: null,
        createdAt: DateTime.utc(2026, 11, 3),
        updatedAt: DateTime.utc(2026, 11, 3),
      ),
    );
    fakes.challenges.emit('c1', _challenge(roomId: 'room1'));
    fakes.playerStates.emit('me', _playerState(incomingChallengeId: 'c1'));
    await _pumpFor(tester);
    expect(find.text('방 초대가 왔어요'), findsOneWidget);
    fakes.challenges.respondResult = (gameId: null, roomId: 'room1');
    await _tap(tester, find.text('수락'));
    fakes.playerStates.emit('me', _playerState(roomId: 'room1'));
    await _pumpFor(tester);
    expect(find.text('상대의 방'), findsOneWidget);
    expect(managers.playerStateManager.playerState?.roomId, 'room1');

    await _tearDown(tester, fakes, 'me');
  });
}
