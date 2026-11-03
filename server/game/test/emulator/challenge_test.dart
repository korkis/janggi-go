@Tags(['emulator'])
library;

import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo_game/firebase/firestore_client.dart';
import 'package:janggigo_game/game_server.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/models/active_game.dart';
import 'package:janggigo_game/models/challenge.dart';
import 'package:janggigo_game/models/game_enums.dart';
import 'package:janggigo_game/models/player_state.dart';
import 'package:janggigo_game/server_environment.dart';
import 'package:test/test.dart';

import 'support/emulator_helpers.dart';

/// 대국실 접속자(`enterLobby`)와 대국 신청 보내기·받기·수락·거절·취소·응답 마감, 연속 거절 제한, 차단, 방 초대 통합 테스트
/// (`docs/server.md`의 신청). `server/game/README.md`의 "테스트"처럼 `firebase emulators:exec`로 실행하면 돈다.
///
/// 응답 시간은 1.5초, 연속 거절 제한은 2초로 줄인다.
void main() {
  final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final skip = emulatorHost == null ? 'FIRESTORE_EMULATOR_HOST가 없습니다. firebase emulators:exec로 실행하세요' : false;
  const responseTime = Duration(milliseconds: 1500);
  const blockTime = Duration(seconds: 2);

  group('접속자와 신청', skip: skip, () {
    late GameServer server;
    late HttpServer httpServer;
    final client = http.Client();
    final random = Random();

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
        testChallengeResponse: responseTime,
        testChallengeBlock: blockTime,
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

    Future<Challenge> getChallenge(String challengeId) async =>
        (await server.repositories.challenges.getChallenge(challengeId))!;

    Future<ActiveGame> getGame(String gameId) async => (await server.repositories.activeGames.getGame(gameId))!;

    Future<void> setConnection(EmulatorAccount account) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return server.rtdb.put('connections/${account.uid}/c1', {
        'online': true,
        'foreground': true,
        'activeSince': now,
        'lastSeenAt': now,
      });
    }

    /// 앱을 켜 대국실에 들어온 계정.
    Future<EmulatorAccount> createPlayer() async {
      final account = await createEmulatorAccount(client, server.firestore);
      await setConnection(account);
      await callResult(account, 'enterLobby');
      return account;
    }

    Future<String> send(EmulatorAccount from, EmulatorAccount to, [Map<String, Object?>? options]) async {
      final result = await callResult(from, 'sendChallenge', {
        'toUid': to.uid,
        ...(options ?? {'senderSide': 'cho'}),
      });
      return result!['challengeId'] as String;
    }

    Future<void> block(EmulatorAccount blocker, EmulatorAccount blocked) {
      return server.firestore.commit([
        SetWrite('users/${blocker.uid}/blocks/${blocked.uid}', {'createdAt': DateTime.now().toUtc()}),
      ]);
    }

    Future<Challenge> waitForStatus(String challengeId, ChallengeStatus status) {
      return waitFor(() async {
        final challenge = await getChallenge(challengeId);
        return challenge.status == status ? challenge : null;
      });
    }

    test('enterLobby는 닉네임, 급수, 상태, 신청 받기를 쓰고 대국 상태를 따라 바꾼다', () async {
      final first = await createPlayer();
      final second = await createPlayer();
      var entry = (await server.repositories.onlineUsers.getOnlineUser(first.uid))!;
      expect(entry.nickname, first.nickname);
      expect(entry.rankLevel, 1);
      expect(entry.status, OnlineStatus.waiting);
      expect(entry.challengesEnabled, isTrue);

      final gameId = await createDevGame(client, httpServer.port, first, second);
      entry = (await server.repositories.onlineUsers.getOnlineUser(first.uid))!;
      expect(entry.status, OnlineStatus.playing);

      await callResult(second, 'resign', {'gameId': gameId});
      await waitFor(() => server.firestore.getDocument('games_archived/$gameId'));
      entry = (await server.repositories.onlineUsers.getOnlineUser(first.uid))!;
      expect(entry.status, OnlineStatus.waiting);

      // 대국실에 없는 사람의 항목은 대국이 생겨도 만들지 않는다.
      await server.rtdb.delete('online_users/${first.uid}');
      await createDevGame(client, httpServer.port, first, second);
      expect(await server.repositories.onlineUsers.getOnlineUser(first.uid), isNull);
      // 들어오면 대국 중으로 쓴다.
      await callResult(first, 'enterLobby');
      expect((await server.repositories.onlineUsers.getOnlineUser(first.uid))!.status, OnlineStatus.playing);
    });

    test('수락하면 보낸 사람이 고른 진영으로 대국을 만들고 두 사람을 묶는다', () async {
      final sender = await createPlayer();
      final target = await createPlayer();
      final challengeId = await send(sender, target, {'senderSide': 'han'});

      var challenge = await getChallenge(challengeId);
      expect(challenge.status, ChallengeStatus.pending);
      expect(challenge.from.nickname, sender.nickname);
      expect(challenge.senderSide, SideChoice.han);
      expect(challenge.timeControl.baseMs, 60000);
      expect((await getPlayerState(sender))?.outgoingChallengeId, challengeId);
      expect((await getPlayerState(target))?.incomingChallengeId, challengeId);
      // 신청 중에는 다른 일을 시작할 수 없다.
      await expectRejected(sender, 'joinQuickQueue', null, 'busy');
      await expectRejected(target, 'createRoom', {'hostSide': 'cho', 'listed': false}, 'busy');
      // 보낸 사람은 응답할 수 없다.
      await expectRejected(sender, 'respondChallenge', {'challengeId': challengeId, 'accepted': true}, 'notFound');

      final result = await callResult(target, 'respondChallenge', {'challengeId': challengeId, 'accepted': true});
      final gameId = result!['gameId'] as String;
      expect(result['roomId'], isNull);
      challenge = await getChallenge(challengeId);
      expect(challenge.status, ChallengeStatus.accepted);
      expect(challenge.gameId, gameId);
      final game = await getGame(gameId);
      expect(game.meta.mode, GameMode.challenge);
      expect(game.meta.rated, isFalse);
      expect(game.meta.listed, isTrue);
      expect(game.meta.players.han.uid, sender.uid);
      expect(game.meta.players.cho.uid, target.uid);
      for (final account in [sender, target]) {
        final state = await getPlayerState(account);
        expect(state?.gameId, gameId);
        expect(state?.outgoingChallengeId, isNull);
        expect(state?.incomingChallengeId, isNull);
      }
      // 끝난 신청에는 다시 응답할 수 없다.
      await expectRejected(target, 'respondChallenge', {'challengeId': challengeId, 'accepted': true}, 'notFound');
      // 대국 중인 사람에게는 신청할 수 없다.
      final third = await createPlayer();
      await expectRejected(third, 'sendChallenge', {'toUid': target.uid, 'senderSide': 'cho'}, 'targetUnavailable');
    });

    test('접장기면 떼는 쪽이 한이다', () async {
      final sender = await createPlayer();
      final target = await createPlayer();
      final challengeId = await send(sender, target, {
        'handicap': {
          'remover': 'opponent',
          'pieces': ['leftChariot'],
        },
      });
      expect((await getChallenge(challengeId)).senderSide, isNull);
      final result = await callResult(target, 'respondChallenge', {'challengeId': challengeId, 'accepted': true});
      final game = await getGame(result!['gameId'] as String);
      expect(game.meta.players.han.uid, target.uid);
      expect(game.meta.handicap, [HandicapPiece.leftChariot]);
    });

    test('한 번에 하나만 보내고 받는다', () async {
      final sender = await createPlayer();
      final target = await createPlayer();
      final other = await createPlayer();
      final challengeId = await send(sender, target);
      // 보내는 사람은 기다리는 동안 다른 신청을 보낼 수 없다.
      await expectRejected(sender, 'sendChallenge', {'toUid': other.uid, 'senderSide': 'cho'}, 'busy');
      // 응답을 기다리는 신청이 있는 사람에게는 보낼 수 없다.
      await expectRejected(other, 'sendChallenge', {'toUid': target.uid, 'senderSide': 'cho'}, 'targetUnavailable');
      await expectRejected(other, 'sendChallenge', {'toUid': sender.uid, 'senderSide': 'cho'}, 'targetUnavailable');

      // 취소하면 두 사람이 풀리고 거절 횟수는 세지 않는다.
      expect(await callResult(sender, 'cancelChallenge', {'challengeId': challengeId}), isNull);
      expect((await getChallenge(challengeId)).status, ChallengeStatus.cancelled);
      expect((await getPlayerState(sender))?.outgoingChallengeId, isNull);
      expect((await getPlayerState(target))?.incomingChallengeId, isNull);
      expect(await server.repositories.challengeLimits.getLimit(sender.uid, target.uid), isNull);
      // 이미 끝났으면 그대로 성공한다. 남의 신청은 취소하지 못한다.
      expect(await callResult(sender, 'cancelChallenge', {'challengeId': challengeId}), isNull);
      await expectRejected(target, 'cancelChallenge', {'challengeId': challengeId}, 'notFound');
      await send(other, target);
    });

    test('대국실에 없거나 신청 받기를 끈 사람에게는 보낼 수 없다', () async {
      final sender = await createPlayer();
      final away = await createEmulatorAccount(client, server.firestore);
      await expectRejected(sender, 'sendChallenge', {'toUid': away.uid, 'senderSide': 'cho'}, 'targetUnavailable');

      final disabled = await createPlayer();
      await server.firestore.commit([
        UpdateWrite('users_private/${disabled.uid}', {'challengesEnabled': false}),
      ]);
      await expectRejected(sender, 'sendChallenge', {'toUid': disabled.uid, 'senderSide': 'cho'}, 'targetUnavailable');

      final roomHost = await createPlayer();
      await callResult(roomHost, 'createRoom', {'hostSide': 'cho', 'listed': false});
      await expectRejected(sender, 'sendChallenge', {'toUid': roomHost.uid, 'senderSide': 'cho'}, 'targetUnavailable');
    });

    test('잘못된 파라미터는 받지 않는다', () async {
      final sender = await createPlayer();
      final target = await createPlayer();
      for (final params in [
        {'toUid': sender.uid, 'senderSide': 'cho'},
        {'toUid': target.uid},
        {
          'toUid': target.uid,
          'senderSide': 'cho',
          'handicap': {
            'remover': 'creator',
            'pieces': ['leftChariot'],
          },
        },
        {'toUid': target.uid, 'senderSide': 'cho', 'roomId': 'room0000000000000000'},
        {'toUid': 'a/b', 'senderSide': 'cho'},
      ]) {
        final (status, body) = await callApi(client, httpServer.port, sender, 'sendChallenge', params);
        expect(status, 400, reason: '$params: $body');
        expect((body['error'] as Map)['status'], 'INVALID_ARGUMENT', reason: '$params');
      }
    });

    test('3번 연속 거절되거나 응답이 없으면 그 상대에게 잠시 신청할 수 없다', () async {
      final sender = await createPlayer();
      final target = await createPlayer();
      for (var i = 0; i < 2; i++) {
        final challengeId = await send(sender, target);
        expect(await callResult(target, 'respondChallenge', {'challengeId': challengeId, 'accepted': false}), {
          'gameId': null,
          'roomId': null,
        });
        expect((await getChallenge(challengeId)).status, ChallengeStatus.declined);
        expect((await getPlayerState(sender))?.outgoingChallengeId, isNull);
        expect((await getPlayerState(target))?.incomingChallengeId, isNull);
      }
      expect((await server.repositories.challengeLimits.getLimit(sender.uid, target.uid))?.failCount, 2);

      // 세 번째는 응답이 없어 마감된다.
      final expiring = await send(sender, target);
      await waitForStatus(expiring, ChallengeStatus.expired);
      expect((await getPlayerState(sender))?.outgoingChallengeId, isNull);
      expect((await getPlayerState(target))?.incomingChallengeId, isNull);
      await expectRejected(target, 'respondChallenge', {'challengeId': expiring, 'accepted': true}, 'notFound');
      final limit = (await server.repositories.challengeLimits.getLimit(sender.uid, target.uid))!;
      expect(limit.failCount, 0);
      expect(limit.blockedUntil, isNotNull);
      await expectRejected(sender, 'sendChallenge', {'toUid': target.uid, 'senderSide': 'cho'}, 'challengeLimited');
      // 반대 방향은 막지 않는다.
      final reverse = await send(target, sender);
      await callResult(target, 'cancelChallenge', {'challengeId': reverse});

      // 제한 시간이 지나면 다시 보낼 수 있고, 수락되면 횟수를 0으로 돌린다.
      await Future<void>.delayed(blockTime);
      final accepted = await send(sender, target);
      await callResult(target, 'respondChallenge', {'challengeId': accepted, 'accepted': true});
      final reset = (await server.repositories.challengeLimits.getLimit(sender.uid, target.uid))!;
      expect(reset.failCount, 0);
      expect(reset.blockedUntil, isNull);
    });

    test('받는 사람이 차단했으면 전달하지 않고 응답 마감에 끝난다', () async {
      final sender = await createPlayer();
      final target = await createPlayer();
      await block(target, sender);
      final challengeId = await send(sender, target);
      expect((await getPlayerState(sender))?.outgoingChallengeId, challengeId);
      expect((await getPlayerState(target))?.incomingChallengeId, isNull);
      // 받는 사람은 그대로 다른 신청을 받는다.
      final other = await createPlayer();
      final otherChallengeId = await send(other, target);
      await callResult(target, 'respondChallenge', {'challengeId': otherChallengeId, 'accepted': false});
      // 전달하지 않은 신청에는 응답할 수 없다.
      await expectRejected(target, 'respondChallenge', {'challengeId': challengeId, 'accepted': true}, 'notFound');

      await waitForStatus(challengeId, ChallengeStatus.expired);
      expect((await getPlayerState(sender))?.outgoingChallengeId, isNull);
      expect((await server.repositories.challengeLimits.getLimit(sender.uid, target.uid))?.failCount, 1);
    });

    test('내가 차단한 사람에게는 보낼 수 없다', () async {
      final sender = await createPlayer();
      final target = await createPlayer();
      await block(sender, target);
      await expectRejected(sender, 'sendChallenge', {'toUid': target.uid, 'senderSide': 'cho'}, 'targetUnavailable');
    });

    test('빠른 대국을 기다리던 사람이 수락하면 대기열에서 뺀다', () async {
      final sender = await createPlayer();
      final target = await createPlayer();
      // 다른 테스트의 대기열 항목과 만나지 않는 레이팅.
      await server.firestore.commit([
        SetWrite('ratings/${target.uid}', {
          'rating': 1e6 + random.nextInt(1 << 30) * 10.0,
          'ratedGames': 0,
          'updatedAt': DateTime.now().toUtc(),
        }),
      ]);
      expect(await callResult(target, 'joinQuickQueue'), {'gameId': null});
      final challengeId = await send(sender, target);
      final result = await callResult(target, 'respondChallenge', {'challengeId': challengeId, 'accepted': true});
      final state = await getPlayerState(target);
      expect(state?.gameId, result!['gameId']);
      expect(state?.quickQueueJoinedAt, isNull);
      expect(await server.repositories.quickQueue.getEntry(target.uid), isNull);
    });

    test('이용 정지 중이면 보낼 수 없다', () async {
      final suspended = await createPlayer();
      final target = await createPlayer();
      await server.firestore.commit([
        UpdateWrite('users_private/${suspended.uid}', {
          'sanction': {'type': 'permanentBan', 'endsAt': null, 'reason': '테스트'},
        }),
      ]);
      await expectRejected(suspended, 'sendChallenge', {'toUid': target.uid, 'senderSide': 'cho'}, 'sanctioned');
    });

    test('방장이 접속자를 초대하면 수락한 사람이 방에 들어온다', () async {
      final host = await createPlayer();
      final invited = await createPlayer();
      final outsider = await createPlayer();
      final roomResult = await callResult(host, 'createRoom', {
        'hostSide': 'han',
        'listed': true,
        'rankRange': {'min': 10, 'max': 27},
      });
      final roomId = roomResult!['roomId'] as String;
      // 방장이 아니면 초대할 수 없다.
      await expectRejected(outsider, 'sendChallenge', {'toUid': invited.uid, 'roomId': roomId}, 'notHost');

      final challengeId = await send(host, invited, {'roomId': roomId});
      final challenge = await getChallenge(challengeId);
      expect(challenge.roomId, roomId);
      expect(challenge.senderSide, SideChoice.han);

      // 방장이 초대한 사람은 급수 범위 밖이어도 들어온다.
      final result = await callResult(invited, 'respondChallenge', {'challengeId': challengeId, 'accepted': true});
      expect(result, {'gameId': null, 'roomId': roomId});
      final room = (await server.repositories.rooms.getRoom(roomId))!;
      expect(room.guestUid, invited.uid);
      expect(room.guest?.nickname, invited.nickname);
      expect((await getPlayerState(invited))?.roomId, roomId);
      expect((await getPlayerState(invited))?.incomingChallengeId, isNull);
      expect((await getPlayerState(host))?.outgoingChallengeId, isNull);
      // 자리가 찼으면 더 초대할 수 없다.
      await expectRejected(host, 'sendChallenge', {'toUid': outsider.uid, 'roomId': roomId}, 'roomFull');
    });

    test('초대를 수락하기 전에 방에 다른 사람이 들어오면 신청이 취소된다', () async {
      final host = await createPlayer();
      final invited = await createPlayer();
      final linkGuest = await createPlayer();
      final roomResult = await callResult(host, 'createRoom', {'hostSide': 'cho', 'listed': false});
      final roomId = roomResult!['roomId'] as String;
      final challengeId = await send(host, invited, {'roomId': roomId});
      await callResult(linkGuest, 'joinRoom', {'roomId': roomId});

      await expectRejected(invited, 'respondChallenge', {'challengeId': challengeId, 'accepted': true}, 'roomFull');
      expect((await getChallenge(challengeId)).status, ChallengeStatus.cancelled);
      expect((await getPlayerState(invited))?.incomingChallengeId, isNull);
      expect((await getPlayerState(invited))?.roomId, isNull);
      expect((await getPlayerState(host))?.outgoingChallengeId, isNull);
    });
  });
}
