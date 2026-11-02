@Tags(['emulator'])
library;

import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:janggigo_game/config.dart';
import 'package:janggigo_game/firebase/firestore_client.dart';
import 'package:janggigo_game/game_server.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/models/active_game.dart';
import 'package:janggigo_game/models/game_enums.dart';
import 'package:janggigo_game/models/player_state.dart';
import 'package:janggigo_game/server_environment.dart';
import 'package:janggigo_game/services/game_rules.dart';
import 'package:janggigo_game/services/rating_rules.dart';
import 'package:test/test.dart';

import 'support/emulator_helpers.dart';

/// 빠른 대국 대기열, 레이팅 매칭, 급수 반영, 다시 두기의 통합 테스트(`docs/server.md`의 빠른 대국, 결과와 레이팅, 다시 두기).
/// `server/game/README.md`의 "테스트"처럼 `firebase emulators:exec`로 실행하면 돈다.
///
/// 같은 에뮬레이터에 다른 테스트나 앱의 대기열 항목이 남아 있을 수 있으므로, 매칭 테스트는 계정마다 다른 테스트와 겹치지 않는
/// 큰 레이팅을 써서 이 테스트의 계정끼리만 만나게 한다. 매칭 범위는 1초마다 넓힌다.
void main() {
  final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final skip = emulatorHost == null ? 'FIRESTORE_EMULATOR_HOST가 없습니다. firebase emulators:exec로 실행하세요' : false;
  const stepInterval = Duration(seconds: 1);

  group('빠른 대국', skip: skip, () {
    late GameServer server;
    late HttpServer httpServer;
    final client = http.Client();
    final random = Random.secure();

    setUpAll(() async {
      server = GameServer.create(
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
        testMatchIntro: Duration.zero,
        testQuickMatchStepInterval: stepInterval,
      );
      httpServer = await server.serve(port: 0);
      await ensureAppConfig(server.firestore);
    });

    tearDownAll(() async {
      client.close();
      await server.close();
    });

    Future<Map<String, Object?>?> callResult(EmulatorAccount account, String api, [Object? data]) async {
      final body = await callApiOk(client, httpServer.port, account, api, data);
      return body['result'] as Map<String, Object?>?;
    }

    Future<void> expectRejected(EmulatorAccount account, String api, Object? data, String code) =>
        expectApiRejected(client, httpServer.port, account, api, data, code);

    Future<PlayerState?> getPlayerState(EmulatorAccount account) =>
        server.repositories.playerStates.getPlayerState(account.uid);

    Future<void> setConnection(EmulatorAccount account, {bool online = true, bool foreground = true}) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return server.rtdb.put('connections/${account.uid}/c1', {
        'online': online,
        'foreground': foreground,
        'activeSince': now,
        'lastSeenAt': now,
      });
    }

    /// 앱을 켜 둔 계정. [rating]을 주면 그 레이팅으로 시작한다.
    Future<EmulatorAccount> createPlayer({double? rating}) async {
      final account = await createEmulatorAccount(client, server.firestore);
      await setConnection(account);
      if (rating != null) {
        await server.firestore.commit([
          SetWrite('ratings/${account.uid}', {'rating': rating, 'ratedGames': 0, 'updatedAt': DateTime.now().toUtc()}),
        ]);
      }
      return account;
    }

    /// 다른 테스트의 대기열 항목과 겹치지 않는 레이팅.
    double isolatedRating() => 1e6 + random.nextInt(1 << 30) * 10.0;

    test('레이팅이 가까운 상대와 매칭하고 두 사람을 대기열에서 빼 대국에 묶는다', () async {
      final base = isolatedRating();
      final first = await createPlayer(rating: base);
      final second = await createPlayer(rating: base + 60);

      expect(await callResult(first, 'joinQuickQueue'), {'gameId': null});
      expect((await getPlayerState(first))?.quickQueueJoinedAt, isNotNull);
      expect(await server.repositories.quickQueue.getEntry(first.uid), isNotNull);

      // 이미 대기열에 있으면 그대로 두고 다시 찾기만 한다.
      expect(await callResult(first, 'joinQuickQueue'), {'gameId': null});

      final gameId = (await callResult(second, 'joinQuickQueue'))?['gameId'] as String?;
      expect(gameId, isNotNull);
      for (final account in [first, second]) {
        final state = await getPlayerState(account);
        expect(state?.gameId, gameId);
        expect(state?.quickQueueJoinedAt, isNull);
        expect(await server.repositories.quickQueue.getEntry(account.uid), isNull);
      }
      final game = (await server.repositories.activeGames.getGame(gameId!))!;
      expect(game.meta.mode, GameMode.quick);
      expect(game.meta.rated, isTrue);
      expect(game.meta.rematchCount, 0);
      expect({game.meta.players.cho.uid, game.meta.players.han.uid}, {first.uid, second.uid});

      // 매칭된 뒤의 그만 찾기는 busy, 대국 중 다시 들어오기도 busy.
      await expectRejected(first, 'leaveQuickQueue', null, 'busy');
      await expectRejected(first, 'joinQuickQueue', null, 'busy');
    });

    test('범위 밖이면 기다렸다가 넓어진 범위로 매칭한다', () async {
      final base = isolatedRating();
      final first = await createPlayer(rating: base);
      final second = await createPlayer(rating: base + 150);

      expect(await callResult(first, 'joinQuickQueue'), {'gameId': null});
      // 첫 사람의 범위 넓히기(1초마다)와 엇갈리게 들어온다.
      await Future<void>.delayed(stepInterval ~/ 2);
      expect(await callResult(second, 'joinQuickQueue'), {'gameId': null});

      // 첫 사람이 1초 기다리면 범위가 150이 되어 예약 작업이 찾는다.
      final gameId = await waitFor(() async => (await getPlayerState(first))?.gameId);
      expect((await getPlayerState(second))?.gameId, gameId);
    });

    test('그만 찾으면 대기열에서 빠지고 다른 사람과 매칭되지 않는다', () async {
      final base = isolatedRating();
      final first = await createPlayer(rating: base);
      final second = await createPlayer(rating: base);

      expect(await callResult(first, 'joinQuickQueue'), {'gameId': null});
      expect(await callResult(first, 'leaveQuickQueue'), isNull);
      expect((await getPlayerState(first))?.quickQueueJoinedAt, isNull);
      expect(await server.repositories.quickQueue.getEntry(first.uid), isNull);
      // 이미 나왔으면 그대로 성공한다.
      expect(await callResult(first, 'leaveQuickQueue'), isNull);

      expect(await callResult(second, 'joinQuickQueue'), {'gameId': null});
      expect(await callResult(second, 'leaveQuickQueue'), isNull);
    });

    test('앱을 화면에 띄워 두지 않은 사람과는 매칭하지 않고, 연결이 없으면 대기열에서 뺀다', () async {
      final base = isolatedRating();
      final away = await createPlayer(rating: base);
      final second = await createPlayer(rating: base);

      expect(await callResult(away, 'joinQuickQueue'), {'gameId': null});
      await setConnection(away, foreground: false);
      expect(await callResult(second, 'joinQuickQueue'), {'gameId': null});
      expect(await callResult(second, 'leaveQuickQueue'), isNull);

      // 앱이 꺼지면(연결이 모두 끊기면) 범위 넓히기 작업이 대기열에서 뺀다.
      await setConnection(away, online: false);
      await waitFor(() async => (await getPlayerState(away))?.quickQueueJoinedAt == null ? true : null);
      expect(await server.repositories.quickQueue.getEntry(away.uid), isNull);
    });

    test('이용 정지 중이면 sanctioned', () async {
      final suspended = await createPlayer();
      await server.firestore.commit([
        UpdateWrite('users_private/${suspended.uid}', {
          'sanction': {
            'type': 'suspension',
            'endsAt': DateTime.now().toUtc().add(const Duration(days: 1)),
            'reason': '테스트',
          },
        }),
      ]);
      await expectRejected(suspended, 'joinQuickQueue', null, 'sanctioned');
    });
  });

  group('급수 반영과 다시 두기', skip: skip, () {
    late GameServer server;
    late HttpServer httpServer;
    final client = http.Client();

    setUpAll(() async {
      server = GameServer.create(
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
        testMatchIntro: Duration.zero,
      );
      httpServer = await server.serve(port: 0);
      await ensureAppConfig(server.firestore);
    });

    tearDownAll(() async {
      client.close();
      await server.close();
    });

    Future<Map<String, Object?>?> callResult(EmulatorAccount account, String api, [Object? data]) async {
      final body = await callApiOk(client, httpServer.port, account, api, data);
      return body['result'] as Map<String, Object?>?;
    }

    Future<void> expectRejected(EmulatorAccount account, String api, Object? data, String code) =>
        expectApiRejected(client, httpServer.port, account, api, data, code);

    Future<ActiveGame> getGame(String gameId) async => (await server.repositories.activeGames.getGame(gameId))!;

    Future<void> setConnection(EmulatorAccount account, {bool online = true}) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return server.rtdb.put('connections/${account.uid}/c1', {
        'online': online,
        'foreground': true,
        'activeSince': now,
        'lastSeenAt': now,
      });
    }

    Future<EmulatorAccount> createPlayer() async {
      final account = await createEmulatorAccount(client, server.firestore);
      await setConnection(account);
      return account;
    }

    /// [cho]와 [han]의 빠른 대국을 대기열을 거치지 않고 바로 만든다. 매칭은 위 그룹에서 본다.
    Future<String> createQuickGame(EmulatorAccount cho, EmulatorAccount han, {int rematchCount = 0}) {
      final now = DateTime.now().toUtc();
      final game = createActiveGame(
        mode: GameMode.quick,
        rated: true,
        listed: true,
        players: GamePlayers(
          cho: GamePlayer(uid: cho.uid, nickname: cho.nickname, rankLevel: 1),
          han: GamePlayer(uid: han.uid, nickname: han.nickname, rankLevel: 1),
        ),
        timeControl: defaultTimeControl,
        disconnectLimitMs: 30000,
        introMs: 0,
        now: now.millisecondsSinceEpoch,
        rematchCount: rematchCount,
        rematchBlocked: rematchCount >= 5,
      );
      return server.gameService.createGame(game, now: now);
    }

    /// [loser]가 기권해 끝내고 기보 저장까지 기다린다.
    Future<void> finishByResignation(String gameId, EmulatorAccount loser) async {
      await callResult(loser, 'resign', {'gameId': gameId});
      await waitFor(() => server.firestore.getDocument('games_archived/$gameId'));
    }

    test('급수 대국이 끝나면 레이팅, 급수, 급수 진행, 급수 변동을 쓴다', () async {
      final winner = await createPlayer();
      final loser = await createPlayer();
      final gameId = await createQuickGame(winner, loser);
      await finishByResignation(gameId, loser);

      final won = getRatedOutcome(rating: initialRating, ratedGames: 0, opponentRating: initialRating, won: true);
      final lost = getRatedOutcome(rating: initialRating, ratedGames: 0, opponentRating: initialRating, won: false);
      for (final (account, outcome) in [(winner, won), (loser, lost)]) {
        final rating = await server.repositories.ratings.getRating(account.uid);
        expect(rating?.rating, closeTo(outcome.rating, 1e-9));
        expect(rating?.ratedGames, 1);
        expect((await server.repositories.users.getUser(account.uid))?.rankLevel, outcome.rankLevel);
        final private = await server.repositories.usersPrivate.getUserPrivate(account.uid);
        expect(private?.rankProgress, closeTo(outcome.rankProgress, 1e-9));
        expect(private?.winsToNextRank, outcome.winsToNextRank);
        final state = await server.repositories.playerStates.getPlayerState(account.uid);
        expect(state?.gameId, isNull);
        expect(state?.lastGameId, gameId);
        final change = state?.lastRankChange;
        expect(change?.gameId, gameId);
        expect(change?.rankLevelBefore, 1);
        expect(change?.rankLevelAfter, outcome.rankLevel);
        expect(change?.rankProgressBefore, 0);
        expect(change?.rankProgressAfter, closeTo(outcome.rankProgress, 1e-9));
      }
      expect(won.rankProgress, closeTo(0.8, 1e-9));
      expect(won.winsToNextRank, 1);
    });

    test('두 사람이 모두 누르면 초와 한을 바꿔 새 급수 대국을 만든다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await createQuickGame(cho, han);
      await finishByResignation(gameId, han);

      expect(await callResult(han, 'requestRematch', {'gameId': gameId}), {'gameId': null});
      expect((await getGame(gameId)).rematch?.han, isTrue);
      // 다시 눌러도 기다린다.
      expect(await callResult(han, 'requestRematch', {'gameId': gameId}), {'gameId': null});

      final rematchGameId = (await callResult(cho, 'requestRematch', {'gameId': gameId}))?['gameId'] as String?;
      expect(rematchGameId, isNotNull);
      expect((await getGame(gameId)).rematch?.gameId, rematchGameId);
      // 늦게 누른 요청도 같은 대국을 돌려받는다.
      expect(await callResult(han, 'requestRematch', {'gameId': gameId}), {'gameId': rematchGameId});

      final rematch = await getGame(rematchGameId!);
      expect(rematch.meta.mode, GameMode.quick);
      expect(rematch.meta.rated, isTrue);
      expect(rematch.meta.rematchOf, gameId);
      expect(rematch.meta.rematchCount, 1);
      expect(rematch.meta.players.cho.uid, han.uid);
      expect(rematch.meta.players.han.uid, cho.uid);
      // 앞 대국을 반영한 급수로 만든다. 진 사람(한)이 지금 초다.
      final hanRankLevel = (await server.repositories.users.getUser(han.uid))!.rankLevel;
      expect(rematch.meta.players.cho.rankLevel, hanRankLevel);
      for (final account in [cho, han]) {
        expect((await server.repositories.playerStates.getPlayerState(account.uid))?.gameId, rematchGameId);
      }
    });

    test('상대가 결과 화면을 나가거나 앱에 없으면 다시 두기를 할 수 없다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final outsider = await createPlayer();
      final gameId = await createQuickGame(cho, han);

      await expectRejected(cho, 'requestRematch', {'gameId': gameId}, 'rematchUnavailable');
      await finishByResignation(gameId, han);
      await expectRejected(outsider, 'requestRematch', {'gameId': gameId}, 'notPlayer');
      await expectRejected(outsider, 'leaveResult', {'gameId': gameId}, 'notPlayer');

      expect(await callResult(cho, 'requestRematch', {'gameId': gameId}), {'gameId': null});
      expect(await callResult(han, 'leaveResult', {'gameId': gameId}), isNull);
      expect((await getGame(gameId)).rematch?.cancelled, isTrue);
      await expectRejected(cho, 'requestRematch', {'gameId': gameId}, 'rematchUnavailable');

      // 결과 화면에서 앱을 끈 상대.
      final secondId = await createQuickGame(cho, han);
      await finishByResignation(secondId, cho);
      await setConnection(han, online: false);
      await expectRejected(cho, 'requestRematch', {'gameId': secondId}, 'rematchUnavailable');
      expect((await getGame(secondId)).rematch?.cancelled, isTrue);

      // 지워진 대국에서 나가기는 그대로 성공한다.
      expect(await callResult(cho, 'leaveResult', {'gameId': 'missingGame000000000'}), isNull);
    });

    test('빠른 대국은 다시 두기 횟수에 닿으면 처음부터 막는다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await createQuickGame(cho, han, rematchCount: 5);
      expect((await getGame(gameId)).rematch?.blocked, isTrue);
      await finishByResignation(gameId, han);
      await expectRejected(han, 'requestRematch', {'gameId': gameId}, 'rematchUnavailable');
    });

    test('급수 대국이 아니면 레이팅을 바꾸지 않는다', () async {
      final cho = await createPlayer();
      final han = await createPlayer();
      final gameId = await createDevGame(client, httpServer.port, cho, han);
      await finishByResignation(gameId, han);
      expect(await server.repositories.ratings.getRating(cho.uid), isNull);
      expect((await server.repositories.playerStates.getPlayerState(cho.uid))?.lastRankChange, isNull);
      expect((await server.repositories.users.getUser(cho.uid))?.rankLevel, 1);
    });
  });
}
