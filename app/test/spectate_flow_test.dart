import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/models/spectate_list_entry.dart';
import 'package:janggigo/utils/spectate_order.dart';
import 'package:janggigo/widgets/adaptive_layout.dart';
import 'package:janggigo/widgets/board/board_view.dart';
import 'package:janggigo/widgets/game_scaffold.dart';
import 'package:janggigo/widgets/spectate_card.dart';
import 'package:janggi_core/janggi_core.dart';

import 'fakes.dart';
import 'online_game_fixtures.dart';

void _useView(WidgetTester tester, Size size, {double devicePixelRatio = 1}) {
  tester.view.physicalSize = size * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

/// 관전 화면의 시계 타이머가 있어 `pumpAndSettle` 대신 시간을 정해 흘린다.
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

final _initialFen = createInitialPosition(
  cho: Formation.horseElephantHorseElephant,
  han: Formation.horseElephantHorseElephant,
).fen;

({String gameId, SpectateListEntry entry}) _entry(
  String gameId, {
  int moveCount = 20,
  int spectatorCount = 0,
  int choRank = 1,
  int hanRank = 1,
  bool handicapped = false,
  int startedAt = 1000,
}) {
  return (
    gameId: gameId,
    entry: SpectateListEntry(
      players: SpectatePlayers(
        cho: SpectatePlayer(nickname: '초$gameId', rankLevel: choRank),
        han: SpectatePlayer(nickname: '한$gameId', rankLevel: hanRank),
      ),
      fen: _initialFen,
      moveCount: moveCount,
      handicapped: handicapped,
      spectatorCount: spectatorCount,
      startedAt: startedAt,
    ),
  );
}

void main() {
  test('10수가 안 된 대국은 뒤로, 관전자 많은 순, 급수 높은 순으로 놓는다', () {
    final sorted = sortSpectateEntries([
      _entry('early', moveCount: 3, spectatorCount: 50),
      _entry('few', spectatorCount: 1, choRank: 27, hanRank: 27),
      _entry('many', spectatorCount: 9),
      _entry('highRank', spectatorCount: 1, choRank: 20, hanRank: 27),
      _entry('lowerRank', spectatorCount: 1, choRank: 10, hanRank: 27),
      _entry('newer', spectatorCount: 1, choRank: 10, hanRank: 27, startedAt: 2000),
    ]);
    expect(sorted.map((item) => item.gameId), ['many', 'few', 'highRank', 'newer', 'lowerRank', 'early']);
  });

  testWidgets('로그인하지 않아도 홈의 볼 만한 대국에서 관전하고, 나가면 관전자 표시를 지운다', (tester) async {
    _useView(tester, const Size(390, 844), devicePixelRatio: 3);
    final fakes = setUpFakeApp();
    fakes.spectateList.entries = [
      _entry('g2', moveCount: 4, spectatorCount: 30),
      _entry('g1', spectatorCount: 2, handicapped: true),
    ];
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    expect(find.text('지금 볼 만한 대국'), findsOneWidget);
    expect(find.byType(SpectateCard), findsNWidgets(2));
    // 10수가 안 된 대국은 관전자가 많아도 뒤에 온다.
    expect(tester.getTopLeft(find.text('초g1 · 18급')).dx, lessThan(tester.getTopLeft(find.text('초g2 · 18급')).dx));
    expect(find.text('접장기'), findsOneWidget);
    expect(find.text('2명'), findsOneWidget);
    expect(find.text('20수째'), findsOneWidget);

    await _tap(tester, find.text('초g1 · 18급'));
    // 상차림 중에는 판 대신 안내를 둔다.
    fakes.games.emit('g1', buildGameJson(cho: 'a', han: 'b'));
    await _pumpFor(tester);
    expect(find.text('대국자가 상차림을 고르고 있어요'), findsOneWidget);

    fakes.spectateList.emit('g1', _entry('g1', spectatorCount: 0).entry);
    fakes.games.emit(
      'g1',
      buildGameJson(cho: 'a', han: 'b', phase: 'playing', turn: 'han', turnStartedAt: 1000000, moves: ['a4b4']),
    );
    await _pumpFor(tester);
    // 서버가 아직 나를 세지 않았어도 1명보다 적게 보여주지 않는다.
    expect(find.text('관전 · 1명 보는 중'), findsOneWidget);
    fakes.spectateList.emit('g1', _entry('g1', spectatorCount: 12).entry);
    await _pumpFor(tester);
    expect(find.text('관전 · 12명 보는 중'), findsOneWidget);
    expect(find.text('초a · 18급'), findsOneWidget);
    expect(find.text('한b · 1단'), findsOneWidget);

    // 남의 대국이므로 어느 쪽 기물도 어둡게 하지 않고, 판을 눌러도 아무 일이 없다. 초가 아래다.
    var board = tester.widget<BoardView>(find.byType(BoardView));
    expect(board.dimmedSide, isNull);
    expect(board.onSquareTap, isNull);
    expect(board.flipped, false);
    expect(tester.getTopLeft(find.text('한b · 1단')).dy, lessThan(tester.getTopLeft(find.text('초a · 18급')).dy));
    await _tap(tester, find.text('판 돌리기'));
    board = tester.widget<BoardView>(find.byType(BoardView));
    expect(board.flipped, true);
    expect(tester.getTopLeft(find.text('초a · 18급')).dy, lessThan(tester.getTopLeft(find.text('한b · 1단')).dy));

    // 관전 채팅은 11번에 붙인다. 지금은 버튼 자리만 있다.
    expect(tester.widget<GameBarButton>(find.widgetWithText(GameBarButton, '관전 채팅')).onPressed, isNull);
    expect(fakes.spectators.spectators, hasLength(1));
    expect(fakes.games.calls, isEmpty);

    await _tap(tester, find.text('나가기'));
    expect(find.text('지금 볼 만한 대국'), findsOneWidget);
    expect(fakes.spectators.calls, ['create g1', 'remove g1']);
    expect(fakes.spectators.spectators, isEmpty);
  });

  testWidgets('관전하던 대국이 끝나면 이긴 쪽 기준 결과를 보여주고, 지워진 대국은 끝났다고 알린다', (tester) async {
    _useView(tester, const Size(390, 844), devicePixelRatio: 3);
    final fakes = setUpFakeApp();
    fakes.spectateList.entries = [_entry('g1')];
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    await _tap(tester, find.text('초g1 · 18급'));
    fakes.games.emit('g1', buildGameJson(cho: 'a', han: 'b', phase: 'playing', turn: 'cho', turnStartedAt: 1000000));
    await _pumpFor(tester);
    fakes.games.emit(
      'g1',
      buildGameJson(
        cho: 'a',
        han: 'b',
        phase: 'finished',
        result: {'winner': 'han', 'reason': 'resignation', 'choScore': 72, 'hanScore': 73.5},
        endedAt: 1060000,
      ),
    );
    await _pumpFor(tester);
    expect(find.text('한 승리'), findsOneWidget);
    expect(find.text('기권승'), findsOneWidget);
    expect(find.text('다시 두기'), findsNothing);
    expect(find.text('한 판 더'), findsNothing);
    expect(find.text('복기하기'), findsOneWidget);

    await _tap(tester, find.widgetWithText(OutlinedButton, '나가기'));
    expect(find.text('지금 볼 만한 대국'), findsOneWidget);
    expect(fakes.spectators.calls, ['create g1', 'remove g1']);

    // 끝난 뒤 RTDB에서 지워진 대국이다.
    fakes.games.emit('g1', null);
    await _tap(tester, find.text('초g1 · 18급'));
    expect(find.text('이미 끝난 대국이에요'), findsOneWidget);
  });

  testWidgets('관전 목록은 진행 중인 대국 수와 카드를 보여주고, 비었거나 읽지 못하면 알린다', (tester) async {
    _useView(tester, const Size(390, 844), devicePixelRatio: 3);
    final fakes = setUpFakeApp();
    fakes.spectateList.entries = [_entry('g1'), _entry('g2'), _entry('g3')];
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    await _tap(tester, find.text('전체 보기'));
    expect(find.text('진행 중인 대국 3개'), findsOneWidget);
    expect(find.byType(SpectateCardGrid), findsOneWidget);

    fakes.spectateList.entries = [];
    await tester.fling(find.text('진행 중인 대국 3개'), const Offset(0, 400), 1000);
    await _pumpFor(tester);
    expect(find.text('지금 볼 수 있는 대국이 없어요'), findsOneWidget);
  });

  testWidgets('1024 이상은 왼쪽 메뉴에 관전을 두고, 관전 화면은 오른쪽 패널에 관전 채팅 자리와 버튼을 둔다', (tester) async {
    _useView(tester, const Size(1440, 900));
    final fakes = setUpFakeApp();
    fakes.spectateList.entries = [_entry('g1', spectatorCount: 4)];
    await tester.pumpWidget(const JanggigoApp());
    await _pumpFor(tester);

    // 홈 오른쪽 칸에 2열 카드로 둔다.
    expect(find.byType(SpectateCardGrid), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byType(SideMenu), matching: find.text('관전')));
    expect(find.text('진행 중인 대국 1개'), findsOneWidget);
    expect(find.byType(SideMenu), findsOneWidget);

    await _tap(tester, find.text('초g1 · 18급'));
    fakes.spectateList.emit('g1', _entry('g1', spectatorCount: 4).entry);
    fakes.games.emit('g1', buildGameJson(cho: 'a', han: 'b', phase: 'playing', turn: 'cho', turnStartedAt: 1000000));
    await _pumpFor(tester);
    expect(find.byType(GamePanel), findsOneWidget);
    expect(find.text('관전 · 4명 보는 중'), findsOneWidget);
    expect(find.text('관전 채팅은 곧 열려요'), findsOneWidget);
    expect(find.text('판 돌리기'), findsOneWidget);
    expect(find.text('관전 채팅'), findsNothing);
    expect(tester.takeException(), isNull);

    await _tap(tester, find.text('나가기'));
    expect(find.text('진행 중인 대국 1개'), findsOneWidget);
  });
}
