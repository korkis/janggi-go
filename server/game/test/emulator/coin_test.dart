@Tags(['emulator'])
library;

import 'dart:io';

import 'package:http/http.dart' as http;
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

/// 참가비, 참가비 돌려주기, 대국 끝 보상의 통합 테스트(`docs/server.md`의 엽전).
/// `server/game/README.md`의 "테스트"처럼 `firebase emulators:exec`로 실행하면 돈다.
void main() {
  final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final skip = emulatorHost == null ? 'FIRESTORE_EMULATOR_HOST가 없습니다. firebase emulators:exec로 실행하세요' : false;

  group('엽전', skip: skip, () {
    late GameServer server;
    late HttpServer httpServer;
    final client = http.Client();

    GameServer createServer() => GameServer.create(
      environment: ServerEnvironment.fromPlatform(),
      logger: GameLogger(format: LogFormat.text, minSeverity: LogSeverity.warning),
      testTimeControl: const TimeControl(
        baseMs: 60000,
        periodMs: 30000,
        periods: 3,
        setupMs: 60000,
        extensionPeriods: 2,
        extensionLimit: 2,
      ),
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

    /// 엽전을 가진 계정.
    Future<EmulatorAccount> createPlayer({int free = 300, int paid = 0, String? rescueDay}) async {
      final account = await createEmulatorAccount(client, server.firestore);
      await server.firestore.commit([
        SetWrite('coin_wallets/${account.uid}', {
          'freeCoins': free,
          'paidCoins': paid,
          'balance': free + paid,
          'attendanceDay': null,
          'attendanceStreak': 0,
          'rescueDay': rescueDay,
          'updatedAt': DateTime.now().toUtc(),
        }),
      ]);
      return account;
    }

    Future<CoinWallet> getWallet(EmulatorAccount account) async =>
        (await server.repositories.coinWallets.getWallet(account.uid))!;

    Future<CoinTransaction?> getTransaction(CoinReason reason, EmulatorAccount account, String key) =>
        server.repositories.coinTransactions.getTransaction(getCoinTransactionId(reason, account.uid, key));

    ActiveGame buildGame(EmulatorAccount cho, EmulatorAccount han, {required GameMode mode, String? roomId}) {
      return createActiveGame(
        mode: mode,
        rated: false,
        listed: true,
        players: GamePlayers(
          cho: GamePlayer(uid: cho.uid, nickname: cho.nickname, rankLevel: 1),
          han: GamePlayer(uid: han.uid, nickname: han.nickname, rankLevel: 1),
        ),
        timeControl: defaultTimeControl,
        disconnectLimitMs: 30000,
        now: DateTime.now().millisecondsSinceEpoch,
        roomId: roomId,
        rematchBlocked: false,
      );
    }

    /// 상차림을 끝내고 초가 한 수를 둔다.
    Future<void> playFirstMove(String gameId, EmulatorAccount cho, EmulatorAccount han) async {
      const formation = 'horseElephantHorseElephant';
      await callOk(han, 'setFormation', {'gameId': gameId, 'formation': formation, 'confirmed': true});
      await callOk(cho, 'setFormation', {'gameId': gameId, 'formation': formation, 'confirmed': true});
      await callOk(cho, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'pass'});
    }

    /// 대국 서버를 거치지 않고 RTDB에서만 [loser]가 기권한 것으로 끝낸다. `finalizeGame`이 아직 돌지 않은 상태다.
    Future<void> finishWithoutFinalizing(String gameId, EmulatorAccount loser) async {
      await server.repositories.activeGames.updateGame(gameId, (game) {
        return resign(game!, requirePlayerSide(game, loser.uid), DateTime.now().millisecondsSinceEpoch);
      });
    }

    test('신청 대국은 참가비를 받고, 끝나면 보상을 주며, 다시 불러도 한 번만 반영한다', () async {
      final cho = await createPlayer(free: 300);
      final han = await createPlayer(free: 5, paid: 100);

      final now = DateTime.now().toUtc();
      final gameId = await server.gameService.createGame(buildGame(cho, han, mode: GameMode.challenge), now: now);

      expect((await getWallet(cho)).balance, 290);
      final hanWallet = await getWallet(han);
      expect([hanWallet.freeCoins, hanWallet.paidCoins], [0, 95]);
      final hanFee = await getTransaction(CoinReason.entryFee, han, gameId);
      expect([hanFee?.freeDelta, hanFee?.paidDelta, hanFee?.gameId], [-5, -5, gameId]);

      await playFirstMove(gameId, cho, han);
      await callOk(han, 'resign', {'gameId': gameId});
      await waitFor(() => server.firestore.getDocument('games_archived/$gameId'));

      expect((await getWallet(cho)).balance, 305);
      final after = await getWallet(han);
      expect([after.freeCoins, after.paidCoins], [5, 95]);

      // 예약 작업이 다시 불러도 그대로다.
      await server.gameService.finalizeGame(gameId, now: DateTime.now().toUtc());
      await server.gameService.finalizeGame(gameId, now: DateTime.now().toUtc());
      expect((await getWallet(cho)).balance, 305);
      expect((await getWallet(han)).balance, 100);
    });

    test('빠른 대국은 참가비를 받고, 수 없이 끝나면 낸 그대로 돌려주며 보상은 없다', () async {
      final cho = await createPlayer(free: 3, paid: 50);
      final han = await createPlayer(free: 100);
      final now = DateTime.now().toUtc();
      final gameId = await server.gameService.createGame(buildGame(cho, han, mode: GameMode.quick), now: now);
      final charged = await getWallet(cho);
      expect([charged.freeCoins, charged.paidCoins], [0, 43]);

      // 상차림 중 나가면 대국이 성립하지 않는다.
      await callOk(cho, 'resign', {'gameId': gameId});
      await waitFor(() => server.firestore.getDocument('games_archived/$gameId'));

      final refunded = await getWallet(cho);
      expect([refunded.freeCoins, refunded.paidCoins], [3, 50]);
      expect((await getWallet(han)).balance, 100);
      expect(await getTransaction(CoinReason.gameReward, han, gameId), isNull);
      final refund = await getTransaction(CoinReason.entryFeeRefund, cho, gameId);
      expect([refund?.freeDelta, refund?.paidDelta], [3, 7]);
    });

    test('방 대국은 참가비도 보상도 없다', () async {
      final host = await createPlayer(free: 100);
      final guest = await createPlayer(free: 100);
      final room = await callOk(host, 'createRoom', {'hostSide': 'cho', 'listed': false});
      final roomId = (room['result'] as Map)['roomId'] as String;
      await callOk(guest, 'joinRoom', {'roomId': roomId});
      final started = await callOk(host, 'startRoomGame', {'roomId': roomId});
      final gameId = (started['result'] as Map)['gameId'] as String;

      expect((await getWallet(host)).balance, 100);
      expect((await getWallet(guest)).balance, 100);

      await playFirstMove(gameId, host, guest);
      await callOk(guest, 'resign', {'gameId': gameId});
      await waitFor(() => server.firestore.getDocument('games_archived/$gameId'));

      expect((await getWallet(host)).balance, 100);
      expect((await getWallet(guest)).balance, 100);
    });

    test('잔액이 모자라면 구제를 주고 받고, 구제도 받았으면 참가비 없이 둔다', () async {
      final today = getCoinDay(DateTime.now());
      final rescued = await createPlayer(free: 2);
      final broke = await createPlayer(free: 2, rescueDay: today);
      final gameId = await server.gameService.createGame(
        buildGame(rescued, broke, mode: GameMode.challenge),
        now: DateTime.now().toUtc(),
      );

      final rescuedWallet = await getWallet(rescued);
      expect([rescuedWallet.balance, rescuedWallet.rescueDay], [42, today]);
      expect((await getTransaction(CoinReason.rescue, rescued, today))?.freeDelta, 50);

      expect((await getWallet(broke)).balance, 2);
      final waived = await getTransaction(CoinReason.entryFee, broke, gameId);
      expect([waived?.freeDelta, waived?.paidDelta], [0, 0]);
      expect(await getTransaction(CoinReason.rescue, broke, today), isNull);
    });

    test('지갑이 없는 사용자도 대국을 시작한다', () async {
      final oldUser = await createEmulatorAccount(client, server.firestore);
      final other = await createPlayer();
      await server.gameService.createGame(
        buildGame(oldUser, other, mode: GameMode.challenge),
        now: DateTime.now().toUtc(),
      );
      expect((await getWallet(oldUser)).balance, 40);
    });

    test('대국자를 묶지 못하면 참가비도 나가지 않는다', () async {
      final cho = await createPlayer(free: 100);
      final han = await createPlayer(free: 100);
      final first = await server.gameService.createGame(
        buildGame(cho, han, mode: GameMode.challenge),
        now: DateTime.now().toUtc(),
      );
      expect((await getWallet(cho)).balance, 90);

      // 이미 대국 중이라 busy로 거절된다.
      await expectLater(
        server.gameService.createGame(buildGame(cho, han, mode: GameMode.challenge), now: DateTime.now().toUtc()),
        throwsA(anything),
      );
      expect((await getWallet(cho)).balance, 90);
      expect((await getWallet(han)).balance, 90);
      expect((await server.repositories.playerStates.getPlayerState(cho.uid))?.gameId, first);
    });

    test('같은 대국 ID로 다시 만들어도 참가비를 두 번 받지 않는다', () async {
      final cho = await createPlayer(free: 100);
      final han = await createPlayer(free: 100);
      final game = buildGame(cho, han, mode: GameMode.challenge);
      final now = DateTime.now().toUtc();
      final gameId = await server.gameService.createGame(game, now: now);
      expect((await getWallet(cho)).balance, 90);

      await server.gameService.createGame(game, now: now, gameId: gameId, check: (transaction, states) async {});

      expect((await getWallet(cho)).balance, 90);
      expect((await getWallet(han)).balance, 90);
    });

    test('finalizeGame이 동시에 여러 번 돌아도 보상은 한 번만 준다', () async {
      final cho = await createPlayer(free: 100);
      final han = await createPlayer(free: 100);
      final gameId = await server.gameService.createGame(
        buildGame(cho, han, mode: GameMode.challenge),
        now: DateTime.now().toUtc(),
      );
      await playFirstMove(gameId, cho, han);
      await finishWithoutFinalizing(gameId, han);

      final now = DateTime.now().toUtc();
      await Future.wait([
        server.gameService.finalizeGame(gameId, now: now),
        server.gameService.finalizeGame(gameId, now: now),
        server.gameService.finalizeGame(gameId, now: now),
      ]);

      expect((await getWallet(cho)).balance, 105);
      expect((await getWallet(han)).balance, 95);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('참가비 쓰기와 대국 끝 쓰기가 잔액을 덮어쓰지 않게 지갑이 내역의 합과 맞는다', () async {
      final cho = await createPlayer(free: 30);
      final han = await createPlayer(free: 30);
      var previousId = await server.gameService.createGame(
        buildGame(cho, han, mode: GameMode.challenge),
        now: DateTime.now().toUtc(),
      );
      for (var index = 0; index < 2; index++) {
        await playFirstMove(previousId, cho, han);
        await callOk(han, 'resign', {'gameId': previousId});
        await waitFor(() => server.firestore.getDocument('games_archived/$previousId'));
        previousId = await server.gameService.createGame(
          buildGame(cho, han, mode: GameMode.challenge),
          now: DateTime.now().toUtc(),
        );
      }
      // 초는 세 번 내고 두 번 이겼다. 한은 세 번 내고 두 번 졌다.
      expect((await getWallet(cho)).balance, 30 - 30 + 30);
      expect((await getWallet(han)).balance, 30 - 30 + 10);
    });

    test('entryFeeEnabled를 끄면 새 대국의 참가비를 받지 않는다', () async {
      final cho = await createPlayer(free: 100);
      final han = await createPlayer(free: 100);
      await server.firestore.commit([
        UpdateWrite('configs/app', {'entryFeeEnabled': false}),
      ]);
      // 캐시 없는 서버로 새 값을 읽는다. `server`의 캐시는 건드리지 않는다.
      final fresh = createServer();
      try {
        final gameId = await fresh.gameService.createGame(
          buildGame(cho, han, mode: GameMode.challenge),
          now: DateTime.now().toUtc(),
        );
        expect((await getWallet(cho)).balance, 100);
        expect(await getTransaction(CoinReason.entryFee, cho, gameId), isNull);
      } finally {
        await server.firestore.commit([
          UpdateWrite('configs/app', {'entryFeeEnabled': true}),
        ]);
        await fresh.close();
      }
    });
  });
}
