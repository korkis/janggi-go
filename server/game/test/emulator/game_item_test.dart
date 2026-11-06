@Tags(['emulator'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo_game/config.dart';
import 'package:janggigo_game/firebase/firestore_client.dart';
import 'package:janggigo_game/game_server.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/models/active_game.dart';
import 'package:janggigo_game/models/coin.dart';
import 'package:janggigo_game/models/game_enums.dart';
import 'package:janggigo_game/server_environment.dart';
import 'package:janggigo_game/services/coin_rules.dart';
import 'package:janggigo_game/services/game_rules.dart';
import 'package:test/test.dart';

import 'support/emulator_helpers.dart';

/// 시간 연장과 대국 중 놓아보기의 통합 테스트(`docs/server.md`의 시간 연장과 놓아보기). 동시 요청과 재시도에도 잔액과 시계가
/// 틀어지지 않는지 본다. `server/game/README.md`의 "테스트"처럼 `firebase emulators:exec`로 실행하면 돈다.
void main() {
  final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final skip = emulatorHost == null ? 'FIRESTORE_EMULATOR_HOST가 없습니다. firebase emulators:exec로 실행하세요' : false;

  group('시간 연장과 놓아보기', skip: skip, () {
    late GameServer server;
    late HttpServer httpServer;
    final client = http.Client();

    GameServer createServer() => GameServer.create(
      environment: ServerEnvironment.fromPlatform(),
      logger: GameLogger(format: LogFormat.text, minSeverity: LogSeverity.error),
    );

    setUpAll(() async {
      server = createServer();
      httpServer = await server.serve(port: 0);
      await ensureAppConfig(server.firestore);
    });

    tearDownAll(() async {
      client.close();
      await server.close();
    });

    Future<Map<String, Object?>> callOk(EmulatorAccount account, String api, Object? data) =>
        callApiOk(client, httpServer.port, account, api, data);

    Future<void> expectRejected(EmulatorAccount account, String api, Object? data, String code) =>
        expectApiRejected(client, httpServer.port, account, api, data, code);

    Future<EmulatorAccount> createPlayer({int free = 300, int paid = 0}) async {
      final account = await createEmulatorAccount(client, server.firestore);
      await server.firestore.commit([
        SetWrite('coin_wallets/${account.uid}', {
          'freeCoins': free,
          'paidCoins': paid,
          'balance': free + paid,
          'attendanceDay': null,
          'attendanceStreak': 0,
          'updatedAt': DateTime.now().toUtc(),
        }),
      ]);
      return account;
    }

    Future<CoinWallet> getWallet(EmulatorAccount account) async =>
        (await server.repositories.coinWallets.getWallet(account.uid))!;

    Future<ActiveGame> getGame(String gameId) async => (await server.repositories.activeGames.getGame(gameId))!;

    /// 상차림까지 끝나 초의 차례인 대국. 참가비 10을 낸 뒤다.
    Future<String> startGame(EmulatorAccount cho, EmulatorAccount han) async {
      final gameId = await server.gameService.createGame(
        createActiveGame(
          mode: GameMode.challenge,
          rated: false,
          listed: true,
          players: GamePlayers(
            cho: GamePlayer(uid: cho.uid, nickname: cho.nickname, rankLevel: 1),
            han: GamePlayer(uid: han.uid, nickname: han.nickname, rankLevel: 1),
          ),
          timeControl: defaultTimeControl,
          disconnectLimitMs: 30000,
          now: DateTime.now().millisecondsSinceEpoch,
          rematchBlocked: false,
        ),
        now: DateTime.now().toUtc(),
      );
      const formation = 'horseElephantHorseElephant';
      await callOk(han, 'setFormation', {'gameId': gameId, 'formation': formation, 'confirmed': true});
      await callOk(cho, 'setFormation', {'gameId': gameId, 'formation': formation, 'confirmed': true});
      return gameId;
    }

    Map<String, Object?> extension(String gameId, int index, {int coinCost = 30}) => {
      'gameId': gameId,
      'extensionIndex': index,
      'coinCost': coinCost,
    };

    Map<String, Object?> practice(String gameId, {int coinCost = 30}) => {'gameId': gameId, 'coinCost': coinCost};

    /// 값만 받은 채 시계를 바꾸기 전에 서버가 멈춘 상태를 만든다.
    Future<void> chargeWithoutApplying(EmulatorAccount account, String gameId, int index) async {
      final wallet = await getWallet(account);
      final plan = planGameItemSpend(
        uid: account.uid,
        wallet: wallet,
        reason: CoinReason.timeExtension,
        gameId: gameId,
        key: getTimeExtensionKey(gameId, index),
        cost: 30,
        now: DateTime.now().toUtc(),
      );
      await server.firestore.runTransaction((transaction) async {
        server.gameService.writeCoinPlanInTransaction(transaction, plan);
      });
    }

    test('내 차례에 쓰면 값을 무상부터 받고 초읽기가 늘어나 시간패 시각이 뒤로 간다', () async {
      final cho = await createPlayer(free: 30, paid: 100);
      final han = await createPlayer();
      final gameId = await startGame(cho, han);
      final before = await getGame(gameId);

      await callOk(cho, 'useTimeExtension', extension(gameId, 0));

      final after = await getGame(gameId);
      expect(after.state.clock.cho.periods, 5);
      expect(after.state.clock.cho.extensionsUsed, 1);
      expect(after.state.clock.cho.baseMs, before.state.clock.cho.baseMs);
      expect(after.state.turn, Side.cho);
      expect(after.state.turnStartedAt, before.state.turnStartedAt);
      expect(after.state.extensionNotice?.side, Side.cho);
      expect(getTimeoutAt(after) - getTimeoutAt(before), 2 * byoyomiPeriod.inMilliseconds);
      final wallet = await getWallet(cho);
      expect([wallet.freeCoins, wallet.paidCoins], [0, 90]);
      final record = await server.repositories.coinTransactions.getTransaction(
        getCoinTransactionId(CoinReason.timeExtension, cho.uid, getTimeExtensionKey(gameId, 0)),
      );
      expect([record?.freeDelta, record?.paidDelta, record?.gameId], [-20, -10, gameId]);
    });

    test('상대 차례에 쓰면 내 횟수만 늘고 상대 시계와 차례는 그대로다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await startGame(cho, han);
      final before = await getGame(gameId);

      await callOk(han, 'useTimeExtension', extension(gameId, 0));

      final after = await getGame(gameId);
      expect(after.state.clock.han.periods, 5);
      expect(after.state.clock.cho.periods, 3);
      expect(after.state.turn, Side.cho);
      expect(after.state.turnStartedAt, before.state.turnStartedAt);
      expect(getTimeoutAt(after), getTimeoutAt(before));
      expect((await getWallet(han)).balance, 260);

      // 차례가 와도 늘어난 횟수가 남아 있다.
      await callOk(cho, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'pass'});
      expect((await getGame(gameId)).state.clock.han.periods, 5);
    });

    test('같은 요청을 다시 보내면 한 번만 반영한다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await startGame(cho, han);

      await callOk(cho, 'useTimeExtension', extension(gameId, 0));
      final version = (await getGame(gameId)).state.version;
      await callOk(cho, 'useTimeExtension', extension(gameId, 0));

      final game = await getGame(gameId);
      expect(game.state.clock.cho.periods, 5);
      expect(game.state.clock.cho.extensionsUsed, 1);
      expect(game.state.version, version);
      expect((await getWallet(cho)).balance, 260);
    });

    test('같은 번호의 요청이 동시에 와도 값과 시계가 한 번만 바뀐다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await startGame(cho, han);

      // 에뮬레이터는 같은 문서의 동시 트랜잭션 일부를 INTERNAL로 끊을 수 있다(README의 Firestore 에뮬레이터의 제약).
      // 그래도 앱이 다시 보내면 한 번만 반영되어야 한다.
      await Future.wait([
        for (var i = 0; i < 4; i++) callApi(client, httpServer.port, cho, 'useTimeExtension', extension(gameId, 0)),
      ]);
      await callOk(cho, 'useTimeExtension', extension(gameId, 0));

      final game = await getGame(gameId);
      expect(game.state.clock.cho.periods, 5);
      expect(game.state.clock.cho.extensionsUsed, 1);
      expect((await getWallet(cho)).balance, 260);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('수와 시간 연장이 동시에 와도 둘 다 반영된다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await startGame(cho, han);

      await Future.wait([
        callOk(cho, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'pass'}),
        callOk(cho, 'useTimeExtension', extension(gameId, 0)),
      ]);

      final game = await getGame(gameId);
      expect(game.moves.length, 1);
      expect(game.state.turn, Side.han);
      expect(game.state.clock.cho.periods, 5);
      expect((await getWallet(cho)).balance, 260);
    });

    test('한 대국에 두 번까지 쓴다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await startGame(cho, han);

      await callOk(cho, 'useTimeExtension', extension(gameId, 0));
      await callOk(cho, 'useTimeExtension', extension(gameId, 1));
      await expectRejected(cho, 'useTimeExtension', extension(gameId, 2), 'extensionLimit');

      expect((await getGame(gameId)).state.clock.cho.periods, 7);
      expect((await getWallet(cho)).balance, 230);
    });

    test('엽전이 모자라거나 값이 바뀌었으면 시계를 바꾸지 않는다', () async {
      final cho = await createPlayer(free: 39);
      final han = await createPlayer();
      final gameId = await startGame(cho, han);

      await expectRejected(cho, 'useTimeExtension', extension(gameId, 0), 'coinsInsufficient');
      await expectRejected(han, 'useTimeExtension', extension(gameId, 0, coinCost: 20), 'coinPriceChanged');

      final game = await getGame(gameId);
      expect(game.state.clock.cho.periods, 3);
      expect(game.state.clock.han.periods, 3);
      expect((await getWallet(cho)).balance, 29);
      expect((await getWallet(han)).balance, 290);
    });

    test('대국자가 아니거나, 상차림 중이거나, 끝난 대국이면 받지 않는다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final other = await createPlayer();
      final gameId = await startGame(cho, han);
      await expectRejected(other, 'useTimeExtension', extension(gameId, 0), 'notPlayer');
      await expectRejected(other, 'useGamePractice', practice(gameId), 'notPlayer');

      await callOk(cho, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'pass'});
      await callOk(han, 'resign', {'gameId': gameId});
      await waitFor(() => server.firestore.getDocument('games_archived/$gameId'));
      final choAfter = (await getWallet(cho)).balance;
      await expectRejected(cho, 'useTimeExtension', extension(gameId, 0), 'gameOver');
      await expectRejected(cho, 'useGamePractice', practice(gameId), 'gameOver');
      expect((await getWallet(cho)).balance, choAfter);

      final a = await createPlayer();
      final b = await createPlayer();
      final setupGameId = await server.gameService.createGame(
        createActiveGame(
          mode: GameMode.challenge,
          rated: false,
          listed: true,
          players: GamePlayers(
            cho: GamePlayer(uid: a.uid, nickname: a.nickname, rankLevel: 1),
            han: GamePlayer(uid: b.uid, nickname: b.nickname, rankLevel: 1),
          ),
          timeControl: defaultTimeControl,
          disconnectLimitMs: 30000,
          now: DateTime.now().millisecondsSinceEpoch,
          rematchBlocked: false,
        ),
        now: DateTime.now().toUtc(),
      );
      await expectRejected(a, 'useTimeExtension', extension(setupGameId, 0), 'notYourTurn');
      await expectRejected(a, 'useGamePractice', practice(setupGameId), 'notYourTurn');
    });

    test('값만 받고 멈췄으면 다시 보낼 때 또 받지 않고 시계만 바꾼다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await startGame(cho, han);
      await chargeWithoutApplying(cho, gameId, 0);
      expect((await getWallet(cho)).balance, 260);

      await callOk(cho, 'useTimeExtension', extension(gameId, 0));

      expect((await getGame(gameId)).state.clock.cho.periods, 5);
      expect((await getWallet(cho)).balance, 260);
    });

    test('값만 받고 멈춘 채 대국이 끝나면 finalizeGame이 한 번만 돌려준다', () async {
      final cho = await createPlayer(free: 20, paid: 30);
      final han = await createPlayer();
      final gameId = await startGame(cho, han);
      await callOk(cho, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'pass'});
      await chargeWithoutApplying(cho, gameId, 0);
      final charged = await getWallet(cho);
      expect([charged.freeCoins, charged.paidCoins], [0, 10]);

      await callOk(han, 'resign', {'gameId': gameId});
      await waitFor(() => server.firestore.getDocument('games_archived/$gameId'));
      await server.gameService.finalizeGame(gameId, now: DateTime.now().toUtc());

      // 참가비 10을 낸 뒤 연장 값 30(무상 10, 유상 20)을 돌려받고 승리 보상 12를 받았다.
      final after = await getWallet(cho);
      expect([after.freeCoins, after.paidCoins], [22, 30]);
      final refund = await server.repositories.coinTransactions.getTransaction(
        getCoinTransactionId(CoinReason.timeExtensionRefund, cho.uid, getTimeExtensionKey(gameId, 0)),
      );
      expect([refund?.freeDelta, refund?.paidDelta], [10, 20]);
    });

    test('시계에 반영된 연장은 대국이 끝나도 돌려주지 않는다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await startGame(cho, han);
      await callOk(cho, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'pass'});
      await callOk(cho, 'useTimeExtension', extension(gameId, 0));

      await callOk(han, 'resign', {'gameId': gameId});
      await waitFor(() => server.firestore.getDocument('games_archived/$gameId'));

      expect((await getWallet(cho)).balance, 300 - 10 - 30 + 12);
    });

    test('놓아보기는 판당 한 번만 받고 내 상태에만 남기며 상대가 보는 곳에는 쓰지 않는다', () async {
      final cho = await createPlayer(free: 10, paid: 100);
      final han = await createPlayer();
      final gameId = await startGame(cho, han);
      final before = await getGame(gameId);

      await callOk(han, 'useGamePractice', practice(gameId));
      await callOk(han, 'useGamePractice', practice(gameId));
      await callOk(cho, 'useGamePractice', practice(gameId));

      expect((await getWallet(han)).balance, 260);
      final wallet = await getWallet(cho);
      expect([wallet.freeCoins, wallet.paidCoins], [0, 70]);
      expect((await server.repositories.playerStates.getPlayerState(han.uid))?.gamePracticeGameId, gameId);
      final after = await getGame(gameId);
      expect(after.state.version, before.state.version);
      expect(jsonEncode(after.toJson()), jsonEncode(before.toJson()));
    });

    test('놓아보기 요청이 동시에 와도 값은 한 번만 받는다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await startGame(cho, han);

      await Future.wait([
        for (var i = 0; i < 4; i++) callApi(client, httpServer.port, cho, 'useGamePractice', practice(gameId)),
      ]);
      await callOk(cho, 'useGamePractice', practice(gameId));

      expect((await getWallet(cho)).balance, 260);
      expect((await server.repositories.playerStates.getPlayerState(cho.uid))?.gamePracticeGameId, gameId);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('놓아보기는 엽전이 모자라거나 값이 바뀌었으면 열지 않는다', () async {
      final cho = await createPlayer(free: 39);
      final han = await createPlayer();
      final gameId = await startGame(cho, han);

      await expectRejected(cho, 'useGamePractice', practice(gameId), 'coinsInsufficient');
      await expectRejected(han, 'useGamePractice', practice(gameId, coinCost: 1), 'coinPriceChanged');

      expect((await server.repositories.playerStates.getPlayerState(cho.uid))?.gamePracticeGameId, isNull);
      expect((await getWallet(cho)).balance, 29);
      expect((await getWallet(han)).balance, 290);
    });

    test('공지가 새 대국을 막으면 시작만 거절하고 진행 중인 대국은 이어 간다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final waiter = await createPlayer();
      final gameId = await startGame(cho, han);
      await server.firestore.commit([
        UpdateWrite('configs/app', {
          'serviceNotice': {'messageKo': '점검 중입니다', 'messageEn': 'Under maintenance', 'gamesBlocked': true},
        }),
      ]);
      // 캐시 없는 서버로 새 값을 읽는다. `server`의 캐시는 건드리지 않는다.
      final fresh = createServer();
      final freshHttp = await fresh.serve(port: 0);
      try {
        await expectApiRejected(client, freshHttp.port, waiter, 'joinQuickQueue', {}, 'gamesBlocked');
        final state = await server.repositories.playerStates.getPlayerState(waiter.uid);
        expect(state?.quickQueueJoinedAt, isNull);
        await expectApiRejected(
          client,
          freshHttp.port,
          waiter,
          'sendChallenge',
          {'toUid': cho.uid, 'senderSide': 'random'},
          'gamesBlocked',
        );
        await callApiOk(client, freshHttp.port, cho, 'useGamePractice', practice(gameId));
        // 방 만들기는 대국이 아니므로 받고, 방의 대국 시작은 거절한다.
        final created = await callApiOk(client, freshHttp.port, waiter, 'createRoom', {
          'hostSide': 'random',
          'listed': false,
        });
        final roomId = (created['result'] as Map)['roomId'] as String;
        final guest = await createPlayer();
        await callApiOk(client, freshHttp.port, guest, 'joinRoom', {'roomId': roomId});
        await expectApiRejected(client, freshHttp.port, waiter, 'startRoomGame', {'roomId': roomId}, 'gamesBlocked');
      } finally {
        await server.firestore.commit([
          UpdateWrite('configs/app', {'serviceNotice': null}),
        ]);
        await fresh.close();
      }
    });

    test('스위치를 끄면 서버가 거절하고, 이미 받은 값은 이어서 처리한다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await startGame(cho, han);
      await chargeWithoutApplying(han, gameId, 0);
      await server.firestore.commit([
        UpdateWrite('configs/app', {'timeExtensionEnabled': false, 'gamePracticeEnabled': false}),
      ]);
      // 캐시 없는 서버로 새 값을 읽는다. `server`의 캐시는 건드리지 않는다.
      final fresh = createServer();
      final freshHttp = await fresh.serve(port: 0);
      try {
        await expectApiRejected(
          client,
          freshHttp.port,
          cho,
          'useTimeExtension',
          extension(gameId, 0),
          'featureDisabled',
        );
        await expectApiRejected(client, freshHttp.port, cho, 'useGamePractice', practice(gameId), 'featureDisabled');
        expect((await getWallet(cho)).balance, 290);
        expect((await getGame(gameId)).state.clock.cho.periods, 3);

        await callApiOk(client, freshHttp.port, han, 'useTimeExtension', extension(gameId, 0));
        expect((await getGame(gameId)).state.clock.han.periods, 5);
        expect((await getWallet(han)).balance, 260);
      } finally {
        await server.firestore.commit([
          UpdateWrite('configs/app', {'timeExtensionEnabled': true, 'gamePracticeEnabled': true}),
        ]);
        await fresh.close();
      }
    });
  });
}
