import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/active_game.dart';
import 'package:janggigo/models/archived_game.dart';
import 'package:janggigo/models/game_enums.dart';
import 'package:janggigo/models/online_user.dart';
import 'package:janggigo/models/user_private.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/profile_screen.dart';
import 'package:janggigo/screens/records_screen.dart';
import 'package:janggigo/screens/user_info_sheet.dart';
import 'package:janggigo/utils/app_exception.dart';
import 'package:janggigo/widgets/adaptive_layout.dart';
import 'package:janggigo/widgets/board/board_view.dart';
import 'package:janggigo/widgets/game_result.dart';

import 'fakes.dart';

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

/// 화면 전환과 닉네임 확인 타이머가 있어 `pumpAndSettle` 대신 시간을 정해 흘린다.
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

UserProfile _profile(
  String nickname, {
  int rankLevel = 1,
  UserStats stats = const UserStats(games: 0, wins: 0, losses: 0),
}) => UserProfile(nickname: nickname, rankLevel: rankLevel, stats: stats, createdAt: DateTime.utc(2026, 11, 3));

UserPrivate _private({int nicknameChangeCount = 0, DateTime? nicknameChangedAt}) => UserPrivate(
  challengesEnabled: true,
  rankProgress: 0.5,
  winsToNextRank: 3,
  nicknameChangeCount: nicknameChangeCount,
  nicknameChangedAt: nicknameChangedAt,
  sanction: null,
);

Future<FakeApp> _signIn(
  String uid,
  String nickname, {
  UserStats stats = const UserStats(games: 0, wins: 0, losses: 0),
}) async {
  final fakes = setUpFakeApp();
  fakes.users.profiles[uid] = _profile(nickname, stats: stats);
  await fakes.auth.signInWithEmail(email: uid, password: 'password');
  await managers.authManager.ensureProfileLoaded();
  return fakes;
}

Widget _app(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

/// [choUid]가 초, [hanUid]가 한으로 둔 끝난 대국. 초의 졸 하나를 옮긴 뒤 [moves]를 더 둔다.
({String gameId, ArchivedGame game}) _archived(
  String gameId, {
  required String choUid,
  required String hanUid,
  required Side winner,
  required GameEndReason reason,
  required DateTime endedAt,
  int choRankLevel = 1,
  int hanRankLevel = 1,
  List<String> moves = const ['a4b4', 'pass', 'pass'],
}) {
  final initial = createInitialPosition(
    cho: Formation.horseElephantHorseElephant,
    han: Formation.horseElephantHorseElephant,
  );
  return (
    gameId: gameId,
    game: ArchivedGame(
      mode: GameMode.quick,
      rated: true,
      playerUids: [choUid, hanUid],
      players: ArchivedPlayers(
        cho: ArchivedPlayer(uid: choUid, rankLevel: choRankLevel),
        han: ArchivedPlayer(uid: hanUid, rankLevel: hanRankLevel),
      ),
      handicap: null,
      initialFen: initial.fen,
      moves: moves,
      result: GameResultRecord(winner: winner, reason: reason, choScore: 72, hanScore: 73.5),
      endedAt: endedAt,
    ),
  );
}

/// 졸과 병을 옆으로 오가는 수. 앞에서부터 몇 수든 잘라 기보로 쓸 수 있다.
const _soldierMoves = ['a4b4', 'a7b7', 'b4a4', 'b7a7', 'a4b4'];

void main() {
  testWidgets('내 기보 목록은 날짜별로 묶어 상대, 결과 종류, 수, 승패를 보여주고 누르면 내 진영을 아래로 복기한다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    fakes.users.profiles['opp'] = _profile('상대', rankLevel: 5);
    final now = DateTime.now().toUtc();
    fakes.archivedGames.games = [
      _archived(
        'g1',
        choUid: 'me',
        hanUid: 'opp',
        winner: Side.cho,
        reason: GameEndReason.checkmate,
        endedAt: now,
        hanRankLevel: 4,
      ),
      _archived(
        'g2',
        choUid: 'gone',
        hanUid: 'me',
        winner: Side.cho,
        reason: GameEndReason.resignation,
        endedAt: now.subtract(const Duration(days: 3)),
        moves: const ['a4b4'],
      ),
    ];
    await tester.pumpWidget(_app(const RecordsScreen()));
    await _pumpFor(tester);

    expect(find.text('새 판에서 놓아보기'), findsOneWidget);
    expect(find.text('오늘'), findsOneWidget);
    // 상대의 급수는 대국 시작 때의 급수다.
    expect(find.text('상대 · 15급'), findsOneWidget);
    expect(find.text('외통승 · 3수'), findsOneWidget);
    // 프로필이 없어진 상대는 알 수 없는 사용자로 보여준다.
    expect(find.text('알 수 없는 사용자 · 18급'), findsOneWidget);
    expect(find.text('기권패 · 1수'), findsOneWidget);
    expect(find.text('승'), findsOneWidget);
    expect(find.text('패'), findsOneWidget);
    expect(find.text('더 보기'), findsNothing);

    await _tap(tester, find.text('기권패 · 1수'));
    expect(find.text('복기'), findsOneWidget);
    expect(find.text('1 / 1수'), findsOneWidget);
    expect(find.text('나 · 18급'), findsOneWidget);
    // 내가 한이었으므로 한이 아래에 오도록 판을 돌린다.
    expect(tester.widget<BoardView>(find.byType(BoardView)).flipped, isTrue);
  });

  testWidgets('홈의 최근 내 대국은 최근 3판을 보여주고, 대국이 끝나 전적이 늘면 다시 읽는다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나', stats: const UserStats(games: 4, wins: 2, losses: 2));
    fakes.users.profiles['opp'] = _profile('상대');
    final now = DateTime.now().toUtc();
    fakes.archivedGames.games = [
      for (var i = 0; i < 4; i++)
        _archived(
          'g$i',
          choUid: i == 0 ? 'opp' : 'me',
          hanUid: i == 0 ? 'me' : 'opp',
          winner: Side.cho,
          reason: GameEndReason.checkmate,
          endedAt: now.subtract(Duration(hours: i)),
          moves: _soldierMoves.take(i + 1).toList(),
        ),
    ];
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    await tester.scrollUntilVisible(find.text('최근 내 대국'), 200);
    await _pumpFor(tester);
    expect(find.text('외통패 · 1수'), findsOneWidget);
    expect(find.text('외통승 · 2수'), findsOneWidget);
    expect(find.text('외통승 · 3수'), findsOneWidget);
    expect(find.text('외통승 · 4수'), findsNothing);

    // 새 대국이 끝나 대국 서버가 기보를 남기고 전적을 더한다.
    fakes.archivedGames.games = [
      _archived(
        'g-new',
        choUid: 'me',
        hanUid: 'opp',
        winner: Side.han,
        reason: GameEndReason.resignation,
        endedAt: now.add(const Duration(minutes: 1)),
        moves: _soldierMoves,
      ),
      ...fakes.archivedGames.games,
    ];
    fakes.users.updateProfile('me', _profile('나', stats: const UserStats(games: 5, wins: 2, losses: 3)));
    await _pumpFor(tester);
    expect(find.text('기권패 · 5수'), findsOneWidget);
    expect(find.text('외통승 · 3수'), findsNothing);

    // 누르면 내 진영을 아래로 복기한다.
    await _tap(tester, find.text('외통패 · 1수'));
    expect(find.text('복기'), findsOneWidget);
    expect(tester.widget<BoardView>(find.byType(BoardView)).flipped, isTrue);
  });

  testWidgets('홈의 최근 내 대국은 로그인하지 않으면 숨기고, 전체 보기로 내 기보 목록에 간다', (tester) async {
    _usePhoneView(tester);
    setUpFakeApp();
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    expect(find.text('최근 내 대국'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    await _signIn('me', '나');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    await tester.scrollUntilVisible(find.text('최근 내 대국'), 200);
    await _pumpFor(tester);
    expect(find.text('아직 끝난 대국이 없어요'), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, '전체 보기').last);
    expect(find.text('내 기보'), findsOneWidget);
  });

  testWidgets('기보를 읽지 못하면 알리고 다시 불러온다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    fakes.archivedGames.nextError = StateError('읽기 실패');
    await tester.pumpWidget(_app(const RecordsScreen()));
    await _pumpFor(tester);
    expect(find.text('기보를 불러오지 못했어요'), findsOneWidget);

    await _tap(tester, find.text('다시 불러오기'));
    expect(find.text('아직 끝난 대국이 없어요'), findsOneWidget);
  });

  testWidgets('홈의 기보 버튼에서 새 판에서 놓아보기로 접장기 상차림을 고르고 양쪽을 자유롭게 둔다', (tester) async {
    _usePhoneView(tester);
    await _signIn('me', '나');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    await _tap(tester, find.text('기보'));
    await _tap(tester, find.text('새 판에서 놓아보기'));
    expect(find.text('접장기로 두려면 한에서 뗄 기물을 골라 주세요'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('왼쪽 차'));
    await _tap(tester, find.text('상차림 고르기'));

    expect(find.text('상차림을 골라 주세요'), findsOneWidget);
    await _tap(tester, find.text('이 상차림으로 정하기'));
    await _tap(tester, find.text('이 상차림으로 정하기'));

    // 놓아보기를 켠 복기 화면으로 연다.
    expect(find.text('놓아보기'), findsWidgets);
    expect(find.byType(TrialBar), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
    final board = tester.widget<BoardView>(find.byType(BoardView));
    expect(board.onSquareTap, isNotNull);
    expect(board.position.pieceAt(Square.parse('a4')), const Piece(Side.cho, PieceType.soldier));
    // 한의 차 하나를 떼고 시작한다.
    final hanChariots = [
      for (final square in ['a10', 'i10']) board.position.pieceAt(Square.parse(square)),
    ].where((piece) => piece == const Piece(Side.han, PieceType.chariot));
    expect(hanChariots, hasLength(1));
  });

  testWidgets('내 정보는 급수, 오늘 전적, 전적과 최근 승패를 보여주고 닉네임을 한 번 바꾼다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나', stats: const UserStats(games: 3, wins: 2, losses: 1));
    fakes.userPrivates.emit('me', _private());
    fakes.users.profiles['opp'] = _profile('상대');
    final now = DateTime.now().toUtc();
    fakes.archivedGames.games = [
      _archived('g1', choUid: 'me', hanUid: 'opp', winner: Side.cho, reason: GameEndReason.timeout, endedAt: now),
      _archived(
        'g2',
        choUid: 'opp',
        hanUid: 'me',
        winner: Side.cho,
        reason: GameEndReason.checkmate,
        endedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    await tester.pumpWidget(_app(const ProfileScreen()));
    await _pumpFor(tester);

    expect(find.text('나'), findsOneWidget);
    expect(find.text('18급'), findsOneWidget);
    expect(find.text('오늘 1승 0패'), findsOneWidget);
    expect(find.text('17급까지 약 3승'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('승'), findsWidgets);
    expect(find.text('차단 목록'), findsOneWidget);

    // 최근 승패를 누르면 그 대국을 복기한다.
    await _tap(tester, find.text('패').last);
    expect(find.text('복기'), findsOneWidget);
    expect(find.text('상대 · 18급'), findsOneWidget);
    await _tap(tester, find.byIcon(Icons.arrow_back_ios_new));

    await _tap(tester, find.byTooltip('닉네임 바꾸기'));
    expect(find.text('바꾸면 7일 동안 다시 바꿀 수 없어요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '나');
    await _pumpFor(tester);
    expect(find.text('지금 쓰는 닉네임이에요'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '바꾸기')).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '장기신');
    await _pumpFor(tester);
    expect(find.text('쓸 수 있는 닉네임이에요'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, '바꾸기'));
    expect(fakes.users.nicknameChanges, ['me 장기신']);
    expect(find.text('닉네임을 바꿨어요'), findsOneWidget);
    expect(find.text('장기신'), findsOneWidget);
  });

  testWidgets('닉네임을 바꾼 지 7일이 지나지 않았거나 엽전이 모자라면 바꾸기를 열지 않고 알린다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    final changedAt = DateTime.now().toUtc().subtract(const Duration(days: 2));
    fakes.userPrivates.emit('me', _private(nicknameChangeCount: 1, nicknameChangedAt: changedAt));
    await tester.pumpWidget(_app(const ProfileScreen()));
    await _pumpFor(tester);

    await _tap(tester, find.byTooltip('닉네임 바꾸기'));
    expect(find.textContaining('부터 다시 바꿀 수 있어요'), findsOneWidget);
    await _tap(tester, find.text('확인'));

    fakes.userPrivates.emit(
      'me',
      _private(nicknameChangeCount: 1, nicknameChangedAt: DateTime.now().toUtc().subtract(const Duration(days: 30))),
    );
    fakes.coinWallets.emit('me', 120);
    await _tap(tester, find.byTooltip('닉네임 바꾸기'));
    expect(find.text('닉네임을 바꾸려면 300엽전이 필요해요. 지금 120엽전이 있어요'), findsOneWidget);
    await _tap(tester, find.text('확인'));
    expect(find.text('바꾸기'), findsNothing);
  });

  testWidgets('두 번째 닉네임 변경은 값을 보여주고 확인을 받은 뒤 엽전을 내고 바꾼다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    fakes.userPrivates.emit(
      'me',
      _private(nicknameChangeCount: 1, nicknameChangedAt: DateTime.now().toUtc().subtract(const Duration(days: 30))),
    );
    fakes.coinWallets.emit('me', 300);
    await tester.pumpWidget(_app(const ProfileScreen()));
    await _pumpFor(tester);

    await _tap(tester, find.byTooltip('닉네임 바꾸기'));
    expect(find.text('300엽전을 내고 바꿔요. 바꾸면 7일 동안 다시 바꿀 수 없어요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '장기신');
    await _pumpFor(tester);

    // 취소하면 바꾸지 않는다.
    await _tap(tester, find.widgetWithText(FilledButton, '바꾸기'));
    expect(find.text('300엽전을 내고 장기신(으)로 바꿀까요?'), findsOneWidget);
    await _tap(tester, find.text('취소'));
    expect(fakes.users.nicknameChanges, isEmpty);

    await _tap(tester, find.widgetWithText(FilledButton, '바꾸기'));
    await _tap(tester, find.widgetWithText(TextButton, '바꾸기'));
    expect(fakes.users.nicknameChanges, ['me 장기신']);
    expect(fakes.users.lastNicknameCoinCost, 300);
    expect(find.text('닉네임을 바꿨어요'), findsOneWidget);
  });

  testWidgets('첫 닉네임 변경은 값을 보내지 않고 확인도 받지 않는다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    fakes.userPrivates.emit('me', _private());
    await tester.pumpWidget(_app(const ProfileScreen()));
    await _pumpFor(tester);

    await _tap(tester, find.byTooltip('닉네임 바꾸기'));
    await tester.enterText(find.byType(TextField), '장기신');
    await _pumpFor(tester);
    await _tap(tester, find.widgetWithText(FilledButton, '바꾸기'));

    expect(fakes.users.nicknameChanges, ['me 장기신']);
    expect(fakes.users.lastNicknameCoinCost, isNull);
  });

  testWidgets('값이 바뀌었거나 엽전이 모자라다고 서버가 거절하면 이유를 알린다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    fakes.userPrivates.emit(
      'me',
      _private(nicknameChangeCount: 1, nicknameChangedAt: DateTime.now().toUtc().subtract(const Duration(days: 30))),
    );
    fakes.coinWallets.emit('me', 500);
    await tester.pumpWidget(_app(const ProfileScreen()));
    await _pumpFor(tester);

    await _tap(tester, find.byTooltip('닉네임 바꾸기'));
    await tester.enterText(find.byType(TextField), '장기신');
    await _pumpFor(tester);

    fakes.users.nextChangeError = const AppException(AppErrorCode.coinPriceChanged);
    await _tap(tester, find.widgetWithText(FilledButton, '바꾸기'));
    await _tap(tester, find.widgetWithText(TextButton, '바꾸기'));
    expect(find.text('값이 바뀌었어요. 다시 열어 주세요'), findsOneWidget);
    await _tap(tester, find.text('확인'));

    fakes.users.nextChangeError = const AppException(AppErrorCode.coinsInsufficient);
    await _tap(tester, find.widgetWithText(FilledButton, '바꾸기'));
    await _tap(tester, find.widgetWithText(TextButton, '바꾸기'));
    expect(find.text('엽전이 모자라요'), findsOneWidget);
    await _tap(tester, find.text('확인'));
    expect(fakes.users.nicknameChanges, isEmpty);
  });

  testWidgets('서버가 닉네임 바꾸기를 거절하면 이유를 알리고 화면에 남는다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    fakes.userPrivates.emit('me', _private());
    fakes.users.nextChangeError = const AppException(AppErrorCode.nicknameChangeCooldown);
    await tester.pumpWidget(_app(const ProfileScreen()));
    await _pumpFor(tester);

    await _tap(tester, find.byTooltip('닉네임 바꾸기'));
    await tester.enterText(find.byType(TextField), '장기신');
    await _pumpFor(tester);
    await _tap(tester, find.widgetWithText(FilledButton, '바꾸기'));
    expect(find.text('닉네임은 바꾼 뒤 7일 동안 다시 바꿀 수 없어요'), findsOneWidget);
    await _tap(tester, find.text('확인'));
    expect(find.widgetWithText(FilledButton, '바꾸기'), findsOneWidget);
    expect(fakes.users.nicknameChanges, isEmpty);
  });

  testWidgets('1024 이상은 기보와 내 정보를 홈 버튼 대신 왼쪽 메뉴에서 연다', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await _signIn('me', '나');
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);
    expect(find.text('기보'), findsOneWidget);
    expect(find.text('내 정보'), findsOneWidget);

    await _tap(tester, find.text('내 정보'));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(SideMenu), findsOneWidget);
    await _tap(tester, find.text('기보'));
    expect(find.byType(RecordsScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다른 사용자 정보에 대국 수, 승률과 나와의 전적을 보여준다', (tester) async {
    _usePhoneView(tester);
    final fakes = await _signIn('me', '나');
    fakes.users.profiles['opp'] = _profile('상대', stats: const UserStats(games: 9, wins: 5, losses: 4));
    final now = DateTime.now().toUtc();
    fakes.archivedGames.games = [
      _archived('g1', choUid: 'me', hanUid: 'opp', winner: Side.cho, reason: GameEndReason.timeout, endedAt: now),
      _archived('g2', choUid: 'opp', hanUid: 'me', winner: Side.cho, reason: GameEndReason.timeout, endedAt: now),
      _archived('g3', choUid: 'opp', hanUid: 'me', winner: Side.han, reason: GameEndReason.timeout, endedAt: now),
    ];
    const user = OnlineUser(
      nickname: '상대',
      rankLevel: 1,
      status: OnlineStatus.waiting,
      challengesEnabled: true,
      since: 0,
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => UserInfoSheet.show(context, uid: 'opp', user: user),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await _tap(tester, find.text('열기'));

    expect(find.text('9판 · 승률 56%'), findsOneWidget);
    expect(find.text('나와의 전적 2승 1패'), findsOneWidget);
    expect(find.text('차단'), findsOneWidget);
  });
}
