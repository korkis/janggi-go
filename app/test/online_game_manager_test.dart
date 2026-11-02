import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/managers/online_game_manager.dart';
import 'package:janggigo/utils/app_exception.dart';

import 'fakes.dart';
import 'online_game_fixtures.dart';

void main() {
  late FakeGameRepository games;
  late OnlineGameManager manager;

  setUp(() {
    games = setUpFakeApp().games;
  });

  tearDown(() {
    manager.dispose();
  });

  group('상차림', () {
    test('한이 먼저 고르고 골라 둔 것과 확정을 서버에 보낸다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'opp');
      expect(manager.loaded, isFalse);
      games.emit('g1', buildGameJson());
      await pumpEventQueue();

      expect(manager.mySide, Side.han);
      expect(manager.canPickFormation, isTrue);
      await manager.pickFormation(Formation.elephantHorseHorseElephant);
      expect(manager.setupPreview.pieceAt(Square.parse('h10'))?.type, PieceType.elephant);
      await manager.confirmFormation();
      expect(games.calls, [
        'setFormation g1 elephantHorseHorseElephant false',
        'setFormation g1 elephantHorseHorseElephant true',
      ]);
    });

    test('초는 한이 확정하기 전에 고르지 못한다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me');
      games.emit('g1', buildGameJson());
      await pumpEventQueue();
      expect(manager.mySide, Side.cho);
      expect(manager.canPickFormation, isFalse);
      await manager.pickFormation(Formation.elephantHorseHorseElephant);
      expect(games.calls, isEmpty);

      games.emit('g1', buildGameJson(setupTurn: 'cho', hanFormation: 'horseElephantElephantHorse'));
      await pumpEventQueue();
      expect(manager.canPickFormation, isTrue);
      expect(manager.hasConfirmedFormation(Side.han), isTrue);
    });
  });

  group('대국', () {
    Map<String, dynamic> playingJson({List<String> moves = const [], Map<String, dynamic>? result}) {
      return buildGameJson(
        phase: result == null ? 'playing' : 'finished',
        setupTurn: 'cho',
        hanFormation: 'horseElephantHorseElephant',
        choFormation: 'horseElephantHorseElephant',
        turn: moves.length.isEven ? 'cho' : 'han',
        turnStartedAt: 1030000,
        moves: moves,
        result: result,
        endedAt: result == null ? null : 1040000,
      );
    }

    test('내 수를 먼저 판에 두고 서버에 보낸다. 답을 기다리는 동안 온 서버 상태로 되돌리지 않는다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me');
      games.emit('g1', playingJson());
      await pumpEventQueue();
      final board = manager.board!;
      expect(board.player, Side.cho);
      expect(board.flipped, isFalse);

      games.playMoveGate = Completer();
      await manager.tapSquare(Square.parse('a4'));
      final sending = manager.tapSquare(Square.parse('b4'));
      await pumpEventQueue();
      expect(games.calls.last, 'playMove g1 0 a4b4');
      expect(board.moveCount, 1);

      games.emit('g1', playingJson());
      await pumpEventQueue();
      expect(board.moveCount, 1);

      games.playMoveGate!.complete();
      await sending;
      games.emit('g1', playingJson(moves: ['a4b4', 'a7b7']));
      await pumpEventQueue();
      expect(board.moveCount, 2);
      expect(board.lastMove, Move.parse('a7b7'));
      expect(board.turn, Side.cho);
    });

    test('상대 차례에는 두지 못한다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'opp');
      games.emit('g1', playingJson());
      await pumpEventQueue();
      expect(manager.board!.flipped, isTrue);
      await manager.tapSquare(Square.parse('a7'));
      await manager.tapSquare(Square.parse('b7'));
      expect(games.calls, isEmpty);
      expect(manager.board!.canPass, isFalse);
    });

    test('서버가 거절하면 서버 상태로 되돌리고 오류를 던진다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me');
      games.emit('g1', playingJson());
      await pumpEventQueue();
      games.nextError = const AppException(AppErrorCode.gameMoveConflict);
      await expectLater(manager.pass(), throwsA(isA<AppException>()));
      expect(manager.board!.moveCount, 0);
    });

    test('서버 결과가 오면 판도 끝난다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me');
      games.emit('g1', playingJson(moves: ['a4b4']));
      await pumpEventQueue();
      games.emit(
        'g1',
        playingJson(moves: ['a4b4'], result: {'winner': 'cho', 'reason': 'timeout', 'choScore': 72, 'hanScore': 73.5}),
      );
      await pumpEventQueue();
      final board = manager.board!;
      expect(board.isOver, isTrue);
      expect(board.result?.winner, Side.cho);
      expect(board.result?.reason, GameEndReason.timeout);
    });

    test('상차림 중 기권으로 끝나도 판을 만든다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me');
      games.emit(
        'g1',
        buildGameJson(
          phase: 'finished',
          result: {'winner': 'cho', 'reason': 'resignation', 'choScore': 72, 'hanScore': 73.5},
          endedAt: 1005000,
        ),
      );
      await pumpEventQueue();
      expect(manager.board?.result?.reason, GameEndReason.resignation);
    });

    test('모르는 결과 사유를 받아도 멈추지 않는다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me');
      games.emit(
        'g1',
        playingJson(result: {'winner': 'han', 'reason': 'somethingNew', 'choScore': 72, 'hanScore': 73.5}),
      );
      await pumpEventQueue();
      expect(manager.game?.state.result?.reason, isNull);
      expect(manager.board?.isOver, isTrue);
    });
  });
}
