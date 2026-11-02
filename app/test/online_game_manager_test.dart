import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/managers/online_game_manager.dart';
import 'package:janggigo/config.dart';
import 'package:janggigo/models/connection.dart';
import 'package:janggigo/utils/app_exception.dart';

import 'fakes.dart';
import 'online_game_fixtures.dart';

void main() {
  late FakeGameRepository games;
  late FakeConnectionRepository connections;
  late FakeAuthRepository auth;
  late OnlineGameManager manager;

  setUp(() {
    final fakes = setUpFakeApp();
    games = fakes.games;
    connections = fakes.connections;
    auth = fakes.auth;
  });

  tearDown(() {
    manager.dispose();
  });

  group('상차림', () {
    test('한이 먼저 고르고 골라 둔 것과 확정을 서버에 보낸다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'opp', connectionManager: managers.connectionManager);
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
      manager = OnlineGameManager(gameId: 'g1', uid: 'me', connectionManager: managers.connectionManager);
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
        // 상대 시계가 0이 되어 checkGame을 부르지 않도록 지금 차례를 시작한다.
        turnStartedAt: DateTime.now().millisecondsSinceEpoch,
        moves: moves,
        result: result,
        endedAt: result == null ? null : 1040000,
      );
    }

    test('내 수를 먼저 판에 두고 서버에 보낸다. 답을 기다리는 동안 온 서버 상태로 되돌리지 않는다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me', connectionManager: managers.connectionManager);
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
      manager = OnlineGameManager(gameId: 'g1', uid: 'opp', connectionManager: managers.connectionManager);
      games.emit('g1', playingJson());
      await pumpEventQueue();
      expect(manager.board!.flipped, isTrue);
      await manager.tapSquare(Square.parse('a7'));
      await manager.tapSquare(Square.parse('b7'));
      expect(games.calls, isEmpty);
      expect(manager.board!.canPass, isFalse);
    });

    test('서버가 거절하면 서버 상태로 되돌리고 오류를 던진다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me', connectionManager: managers.connectionManager);
      games.emit('g1', playingJson());
      await pumpEventQueue();
      games.nextError = const AppException(AppErrorCode.gameMoveConflict);
      await expectLater(manager.pass(), throwsA(isA<AppException>()));
      expect(manager.board!.moveCount, 0);
    });

    test('서버 결과가 오면 판도 끝난다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me', connectionManager: managers.connectionManager);
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
      manager = OnlineGameManager(gameId: 'g1', uid: 'me', connectionManager: managers.connectionManager);
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
      manager = OnlineGameManager(gameId: 'g1', uid: 'me', connectionManager: managers.connectionManager);
      games.emit(
        'g1',
        playingJson(result: {'winner': 'han', 'reason': 'somethingNew', 'choScore': 72, 'hanScore': 73.5}),
      );
      await pumpEventQueue();
      expect(manager.game?.state.result?.reason, isNull);
      expect(manager.board?.isOver, isTrue);
    });
  });

  group('접속 끊김', () {
    const online = Connection(online: true, foreground: true, activeSince: 1000, lastSeenAt: 2000);
    const offline = Connection(online: false, foreground: true, activeSince: 1000, lastSeenAt: 3000);

    Map<String, dynamic> playingJson({int version = 1, int? opponentSince, int? mySince, String turn = 'cho'}) {
      final json = buildGameJson(
        phase: 'playing',
        setupTurn: 'cho',
        hanFormation: 'horseElephantHorseElephant',
        choFormation: 'horseElephantHorseElephant',
        turn: turn,
        turnStartedAt: DateTime.now().millisecondsSinceEpoch,
        disconnect: {
          'cho': {'usedMs': 0, 'since': ?mySince},
          'han': {'usedMs': 4000, 'since': ?opponentSince},
        },
      );
      (json['state'] as Map<String, dynamic>)['version'] = version;
      return json;
    }

    test('상대가 끊긴 것을 보면 checkGame을 부르고, 서버가 기록하면 다시 부르지 않는다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me', connectionManager: managers.connectionManager);
      games.emit('g1', playingJson());
      await pumpEventQueue();
      connections.emitConnections('opp', [online]);
      await pumpEventQueue();
      expect(games.calls, isEmpty);

      connections.emitConnections('opp', [offline]);
      await pumpEventQueue();
      expect(games.calls, ['checkGame g1']);
      // 같은 서버 상태에서는 다시 부르지 않는다.
      games.emit('g1', playingJson());
      await pumpEventQueue();
      expect(games.calls, ['checkGame g1']);

      games.emit('g1', playingJson(version: 2, opponentSince: 3000));
      await pumpEventQueue();
      expect(games.calls, ['checkGame g1']);

      // 돌아왔는데 서버 기록이 남아 있으면 다시 부른다.
      connections.emitConnections('opp', [online]);
      await pumpEventQueue();
      expect(games.calls, ['checkGame g1', 'checkGame g1']);
    });

    test('서버가 나를 끊긴 것으로 기록했는데 연결되어 있으면 activeSince를 새로 쓰고 checkGame을 부른다', () async {
      await auth.signInWithEmail(email: 'me', password: 'password');
      await pumpEventQueue();
      expect(managers.connectionManager.active, isTrue);
      manager = OnlineGameManager(gameId: 'g1', uid: 'me', connectionManager: managers.connectionManager);
      games.emit('g1', playingJson(mySince: 3000));
      await pumpEventQueue();
      expect(connections.writes, ['create me true', 'foreground me c1']);
      expect(games.calls, ['checkGame g1']);
    });

    test('상대 시계가 0이 되면 차례마다 한 번 checkGame을 부른다', () async {
      manager = OnlineGameManager(gameId: 'g1', uid: 'me', connectionManager: managers.connectionManager);
      final json = playingJson(turn: 'han');
      (json['state'] as Map<String, dynamic>)['turnStartedAt'] = 1030000;
      games.emit('g1', json);
      await Future<void>.delayed(gameClockTickInterval * 3);
      expect(games.calls, ['checkGame g1']);
    });
  });
}
