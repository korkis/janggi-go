import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/game_enums.dart';
import 'package:janggigo/models/player_state.dart';
import 'package:janggigo/models/room.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/utils/app_exception.dart';
import 'package:janggigo/utils/invite_link.dart';

import 'fakes.dart';
import 'online_game_fixtures.dart';

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

/// 대국 화면의 시계 타이머가 있어 `pumpAndSettle` 대신 시간을 정해 흘린다.
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

PlayerState _playerState({String? roomId, String? gameId}) {
  return PlayerState(
    roomId: roomId,
    gameId: gameId,
    lastGameId: null,
    outgoingChallengeId: null,
    incomingChallengeId: null,
    setupDraft: null,
    lastRankChange: null,
    gamePracticeGameId: null,
    quickQueueJoinedAt: null,
    updatedAt: DateTime.utc(2026, 11, 2),
  );
}

UserProfile _profile(String nickname) {
  return UserProfile(
    nickname: nickname,
    rankLevel: 1,
    stats: const UserStats(games: 0, wins: 0, losses: 0),
    createdAt: DateTime.utc(2026, 11, 2),
  );
}

/// [hostUid]가 방장인 방. [guest]를 주면 그 사람이 상대 자리에 있다.
Room _room({
  String hostUid = 'me',
  String? guest,
  RoomStatus status = RoomStatus.waiting,
  bool listed = true,
  List<String> kickedUids = const [],
  RoomHandicap? handicap,
  RankRange? rankRange,
  String? gameId,
}) {
  return Room(
    hostUid: hostUid,
    host: RoomPlayer(nickname: '방장$hostUid', rankLevel: 1),
    guestUid: guest,
    guest: guest == null ? null : RoomPlayer(nickname: '상대$guest', rankLevel: 19),
    status: status,
    listed: listed,
    hostSide: SideChoice.cho,
    handicap: handicap,
    rankRange: rankRange,
    gameId: gameId,
    kickedUids: kickedUids,
    hostAbsentSince: null,
    guestAbsentSince: null,
    createdAt: DateTime.utc(2026, 11, 2),
    updatedAt: DateTime.utc(2026, 11, 2),
  );
}

/// [uid]로 로그인한 채 홈을 띄운다. 초대 링크도 받기 시작한다.
Future<FakeApp> _startSignedIn(WidgetTester tester, String uid) async {
  _usePhoneView(tester);
  final fakes = setUpFakeApp();
  fakes.users.profiles[uid] = _profile('나$uid');
  await fakes.auth.signInWithEmail(email: uid, password: 'password');
  managers.inviteLinkManager.start();
  await tester.pumpWidget(const JanggigoApp());
  await _pumpFor(tester);
  return fakes;
}

Future<void> _tearDown(WidgetTester tester, FakeApp fakes, String uid) async {
  fakes.playerStates.emit(uid, null);
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  test('초대 링크와 설치 정보에서 방 ID를 읽는다', () {
    expect(buildInviteLink('abc123').toString(), 'https://janggigo.zupion.com/r/abc123');
    expect(getInviteRoomId(Uri.parse('https://janggigo.zupion.com/r/abc123'), web: false), 'abc123');
    expect(getInviteRoomId(Uri.parse('janggigo://r/abc123'), web: false), 'abc123');
    expect(getInviteRoomId(Uri.parse('https://janggigo.zupion.com/?room=abc123'), web: true), 'abc123');
    expect(getInviteRoomId(Uri.parse('https://example.com/r/abc123'), web: false), isNull);
    expect(getInviteRoomId(Uri.parse('https://janggigo.zupion.com/r/abc123/x'), web: false), isNull);
    expect(getInviteRoomId(Uri.parse('https://janggigo.zupion.com/r/a.b'), web: false), isNull);
    expect(getInviteRoomId(Uri.parse('https://janggigo.zupion.com/'), web: true), isNull);
    expect(getInstallReferrerRoomId('room=abc123'), 'abc123');
    expect(getInstallReferrerRoomId('utm_source=google-play&utm_medium=organic'), isNull);
  });

  testWidgets('방을 만들면 방 대기실에서 링크를 보여주고, 상대가 들어오면 방장이 대국을 시작해 상차림으로 간다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');

    await _tap(tester, find.text('방 만들기'));
    expect(find.text('내 진영'), findsOneWidget);
    await _tap(tester, find.text('접장기'));
    expect(find.text('떼는 쪽이 한을 잡아요'), findsOneWidget);
    expect(find.text('뗄 기물을 골라 주세요'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '방 만들기')).onPressed, isNull);
    await _tap(tester, find.text('상대'));
    await _tap(tester, find.bySemanticsLabel('왼쪽 차'));
    await _tap(tester, find.bySemanticsLabel('오른쪽 포'));
    expect(find.text('차, 포 떼기 · 20점 적게 시작'), findsOneWidget);
    await _tap(tester, find.text('방 목록에 공개'));
    expect(find.text('초대 링크로만 들어올 수 있어요'), findsOneWidget);
    expect(find.text('들어올 수 있는 급수'), findsNothing);

    fakes.rooms.emit(
      'room1',
      _room(
        listed: false,
        handicap: const RoomHandicap(
          remover: HandicapRemover.opponent,
          pieces: [HandicapPiece.leftChariot, HandicapPiece.rightCannon],
        ),
      ),
    );
    await _tap(tester, find.widgetWithText(FilledButton, '방 만들기'));
    expect(fakes.rooms.calls, ['createRoom random unlisted opponent leftChariot,rightCannon null']);
    expect(find.text('방장me의 방'), findsOneWidget);
    expect(find.text('접장기'), findsOneWidget);
    expect(find.text('상대가 떼요'), findsOneWidget);
    expect(find.text('비공개'), findsOneWidget);
    expect(find.text('상대를 기다리고 있어요'), findsOneWidget);
    expect(find.text('https://janggigo.zupion.com/r/room1'), findsOneWidget);
    expect(find.text('상대가 들어오면 시작할 수 있어요'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '대국 시작')).onPressed, isNull);

    fakes.rooms.emit('room1', _room(guest: 'opp', listed: false));
    await _pumpFor(tester);
    expect(find.text('상대opp · 1단'), findsOneWidget);
    expect(find.text('내보내기'), findsOneWidget);
    expect(find.text('초대 링크로 부르기'), findsNothing);

    await _tap(tester, find.text('대국 시작'));
    expect(fakes.rooms.calls.last, 'startRoomGame room1');
    fakes.games.emit('g1', buildGameJson(roomId: 'room1', mode: 'room'));
    fakes.playerStates.emit('me', _playerState(roomId: 'room1', gameId: 'g1'));
    await _pumpFor(tester);
    expect(find.text('상차림을 골라 주세요'), findsOneWidget);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('방장이 상대를 내보내고, 방장이 나가면 한 번 묻고 방을 닫는다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.rooms.emit('room1', _room(guest: 'opp'));
    fakes.playerStates.emit('me', _playerState(roomId: 'room1'));
    await _pumpFor(tester);

    await _tap(tester, find.text('방으로 돌아가기'));
    expect(find.text('방장me의 방'), findsOneWidget);
    expect(find.text('방장 초'), findsOneWidget);
    expect(find.text('공개'), findsOneWidget);
    expect(find.text('모든 급수'), findsOneWidget);

    await _tap(tester, find.text('내보내기'));
    expect(find.text('상대opp님을 내보낼까요? 이 방에 다시 들어올 수 없어요'), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('내보내기')));
    expect(fakes.rooms.calls, ['kickGuest room1']);

    await tester.tap(find.byType(BackButton));
    await _pumpFor(tester);
    expect(find.text('방을 나가면 방이 닫혀요. 나갈까요?'), findsOneWidget);
    await _tap(tester, find.text('나가기'));
    expect(fakes.rooms.calls.last, 'leaveRoom room1');
    // 서버가 방을 닫아도 직접 나간 방장에게는 알리지 않는다.
    fakes.rooms.emit('room1', _room(status: RoomStatus.closed));
    await _pumpFor(tester);
    expect(find.text('방이 닫혔어요'), findsNothing);
    expect(find.text('빠른 대국'), findsOneWidget);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('초대 링크를 누르면 방에 들어가고, 방장이 내보내면 알린 뒤 나온다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.rooms.emit('room1', _room(hostUid: 'opp', guest: 'me'));

    fakes.deepLinks.emit(Uri.parse('https://janggigo.zupion.com/r/room1'));
    await _pumpFor(tester);
    expect(fakes.rooms.calls, ['joinRoom room1']);
    expect(find.text('방장opp의 방'), findsOneWidget);
    expect(find.text('방장이 대국을 시작하면 바로 상차림으로 가요'), findsOneWidget);
    expect(find.text('내보내기'), findsNothing);
    expect(find.text('대국 시작'), findsNothing);

    fakes.rooms.emit('room1', _room(hostUid: 'opp', kickedUids: ['me']));
    await _pumpFor(tester);
    expect(find.text('방장이 내보냈어요'), findsOneWidget);
    await _tap(tester, find.text('확인'));
    expect(find.text('빠른 대국'), findsOneWidget);
    expect(fakes.rooms.calls, ['joinRoom room1']);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('초대받은 방이 대국 중이면 관전을 권하고, 고르면 그 대국을 관전한다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.rooms.emit('room1', _room(hostUid: 'opp', guest: 'x', status: RoomStatus.playing, gameId: 'g1'));
    fakes.rooms.nextError = const AppException(AppErrorCode.roomFull);

    fakes.deepLinks.emit(Uri.parse('janggigo://r/room1'));
    await _pumpFor(tester);
    expect(find.text('지금 대국 중인 방이에요. 관전할까요?'), findsOneWidget);
    await _tap(tester, find.text('취소'));
    expect(find.text('빠른 대국'), findsOneWidget);

    fakes.rooms.nextError = const AppException(AppErrorCode.roomFull);
    fakes.deepLinks.emit(Uri.parse('janggigo://r/room1'));
    await _pumpFor(tester);
    await _tap(tester, find.text('관전하기'));
    // 비공개 방 대국은 관전 목록에 없어 관전자 수 없이 "관전"만 쓴다.
    fakes.games.emit('g1', buildGameJson(cho: 'opp', han: 'x', phase: 'playing', turn: 'cho', roomId: 'room1'));
    await _pumpFor(tester);
    expect(find.text('관전'), findsOneWidget);
    // 판 돌리기는 두지 않는다.
    expect(find.text('판 돌리기'), findsNothing);
    expect(fakes.spectators.calls, ['create g1']);

    await _tap(tester, find.text('나가기'));
    expect(find.text('빠른 대국'), findsOneWidget);
    expect(fakes.spectators.calls, ['create g1', 'remove g1']);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('링크로 설치하고 처음 켜면 로그인과 닉네임을 거쳐 그 방으로 간다', (tester) async {
    _usePhoneView(tester);
    final fakes = setUpFakeApp();
    fakes.deepLinks.installReferrer = 'room=room1';
    managers.inviteLinkManager.start();
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(find.text('로그인하면 바로\n초대받은 방에 들어가요'), findsOneWidget);
    await _tap(tester, find.text('Google로 계속하기'));
    expect(find.text('정하고 나면 바로 방에 들어가요'), findsOneWidget);
    expect(fakes.rooms.calls, isEmpty);
    // 설치 정보는 한 번만 읽는다.
    expect(fakes.deepLinks.installReferrer, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('대국실 방 목록에서 방에 들어가고, 나오면 목록을 다시 읽는다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.rooms.rooms = [
      (
        id: 'room2',
        room: _room(
          hostUid: 'opp',
          handicap: const RoomHandicap(remover: HandicapRemover.creator, pieces: [HandicapPiece.leftChariot]),
          rankRange: const RankRange(min: 1, max: 10),
        ),
      ),
    ];
    fakes.rooms.emit('room2', _room(hostUid: 'opp', guest: 'me'));

    await _tap(tester, find.text('대국실'));
    expect(fakes.rooms.calls, ['getRooms']);
    expect(find.text('방장opp · 18급'), findsOneWidget);
    expect(find.text('접장기'), findsOneWidget);
    expect(find.text('방장이 떼요'), findsOneWidget);
    expect(find.text('18급 ~ 9급'), findsOneWidget);
    expect(find.text('공개'), findsNothing);

    await _tap(tester, find.text('입장'));
    expect(fakes.rooms.calls, ['getRooms', 'joinRoom room2']);
    expect(find.text('방장opp의 방'), findsOneWidget);

    // 상대는 묻지 않고 나간다.
    fakes.rooms.rooms = [];
    await tester.tap(find.byType(BackButton));
    await _pumpFor(tester);
    expect(fakes.rooms.calls, ['getRooms', 'joinRoom room2', 'leaveRoom room2', 'getRooms']);
    expect(find.text('지금 열린 방이 없어요'), findsOneWidget);

    await _tearDown(tester, fakes, 'me');
  });

  testWidgets('방 대국이 끝난 화면을 나가면 방 대기실로 돌아간다', (tester) async {
    final fakes = await _startSignedIn(tester, 'me');
    fakes.rooms.emit('room1', _room(hostUid: 'opp', guest: 'me', status: RoomStatus.playing, gameId: 'g1'));
    fakes.playerStates.emit('me', _playerState(roomId: 'room1'));
    await _pumpFor(tester);
    await _tap(tester, find.text('방으로 돌아가기'));

    fakes.games.emit(
      'g1',
      buildGameJson(
        roomId: 'room1',
        mode: 'room',
        phase: 'finished',
        setupTurn: 'cho',
        hanFormation: 'horseElephantHorseElephant',
        choFormation: 'horseElephantHorseElephant',
        turn: 'cho',
        turnStartedAt: 1030000,
        result: {'winner': 'cho', 'reason': 'resignation', 'choScore': 72, 'hanScore': 73.5},
        endedAt: 1040000,
      ),
    );
    fakes.playerStates.emit('me', _playerState(roomId: 'room1', gameId: 'g1'));
    await _pumpFor(tester);
    expect(find.text('승리 · 기권승'), findsOneWidget);
    expect(find.text('한 판 더'), findsNothing);
    expect(find.text('나가기'), findsNothing);

    fakes.rooms.emit('room1', _room(hostUid: 'opp', guest: 'me', gameId: 'g1'));
    fakes.playerStates.emit('me', _playerState(roomId: 'room1'));
    await _tap(tester, find.text('방 대기실로'));
    expect(fakes.games.calls, ['leaveResult g1']);
    expect(find.text('방장opp의 방'), findsOneWidget);
    expect(find.text('방장이 대국을 시작하면 바로 상차림으로 가요'), findsOneWidget);

    await _tearDown(tester, fakes, 'me');
  });
}
