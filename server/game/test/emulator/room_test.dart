@Tags(['emulator'])
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo_game/firebase/firestore_client.dart';
import 'package:janggigo_game/game_server.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/models/active_game.dart';
import 'package:janggigo_game/models/game_enums.dart';
import 'package:janggigo_game/models/player_state.dart';
import 'package:janggigo_game/models/room.dart';
import 'package:janggigo_game/server_environment.dart';
import 'package:test/test.dart';

import 'support/emulator_helpers.dart';

/// 방 만들기, 들어가기, 내보내기, 대국 시작, 방 유지, 방 대국의 다시 두기 통합 테스트(`docs/server.md`의 방).
/// `server/game/README.md`의 "테스트"처럼 `firebase emulators:exec`로 실행하면 돈다.
///
/// 방 연결 확인(`checkRoom`)은 0.5초마다, 연결이 1초 없으면 방을 닫거나 자리를 비운다. 다른 테스트의 계정은 연결을 켜 둔다.
void main() {
  final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final skip = emulatorHost == null ? 'FIRESTORE_EMULATOR_HOST가 없습니다. firebase emulators:exec로 실행하세요' : false;
  const absentLimit = Duration(seconds: 1);

  group('방', skip: skip, () {
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
        testRoomCheckInterval: const Duration(milliseconds: 500),
        testRoomAbsentLimit: absentLimit,
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

    Future<Room> getRoom(String roomId) async => (await server.repositories.rooms.getRoom(roomId))!;

    Future<ActiveGame> getGame(String gameId) async => (await server.repositories.activeGames.getGame(gameId))!;

    Future<void> setConnection(EmulatorAccount account, {bool online = true}) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return server.rtdb.put('connections/${account.uid}/c1', {
        'online': online,
        'foreground': online,
        'activeSince': now,
        'lastSeenAt': now,
      });
    }

    Future<EmulatorAccount> createPlayer() async {
      final account = await createEmulatorAccount(client, server.firestore);
      await setConnection(account);
      return account;
    }

    Future<String> createRoom(EmulatorAccount host, Map<String, Object?> options) async {
      final result = await callResult(host, 'createRoom', options);
      return result!['roomId'] as String;
    }

    Future<String> startGame(EmulatorAccount host, String roomId) async {
      final result = await callResult(host, 'startRoomGame', {'roomId': roomId});
      return result!['gameId'] as String;
    }

    /// [loser]가 기권해 끝내고 기보 저장까지 기다린다.
    Future<void> finishByResignation(String gameId, EmulatorAccount loser) async {
      await callResult(loser, 'resign', {'gameId': gameId});
      await waitFor(() => server.firestore.getDocument('games_archived/$gameId'));
    }

    test('방을 만들고 상대가 들어오면 방장이 내보낼 수 있고 내보낸 사람은 다시 못 들어온다', () async {
      final host = await createPlayer();
      final guest = await createPlayer();
      final third = await createPlayer();
      final roomId = await createRoom(host, {'hostSide': 'random', 'listed': true});

      var room = await getRoom(roomId);
      expect(room.status, RoomStatus.waiting);
      expect(room.hostUid, host.uid);
      expect(room.host.nickname, host.nickname);
      expect(room.guestUid, isNull);
      expect((await getPlayerState(host))?.roomId, roomId);
      // 방에 있으면 다른 방, 빠른 대국을 시작할 수 없다.
      await expectRejected(host, 'createRoom', {'hostSide': 'cho', 'listed': false}, 'busy');
      await expectRejected(host, 'joinQuickQueue', null, 'busy');
      await expectRejected(host, 'startRoomGame', {'roomId': roomId}, 'notFound');

      expect(await callResult(guest, 'joinRoom', {'roomId': roomId}), isNull);
      // 이미 들어와 있으면 그대로 성공한다.
      expect(await callResult(guest, 'joinRoom', {'roomId': roomId}), isNull);
      room = await getRoom(roomId);
      expect(room.guestUid, guest.uid);
      expect(room.guest?.nickname, guest.nickname);
      expect((await getPlayerState(guest))?.roomId, roomId);
      await expectRejected(third, 'joinRoom', {'roomId': roomId}, 'roomFull');

      await expectRejected(guest, 'kickGuest', {'roomId': roomId}, 'notHost');
      await expectRejected(guest, 'startRoomGame', {'roomId': roomId}, 'notHost');
      expect(await callResult(host, 'kickGuest', {'roomId': roomId}), isNull);
      room = await getRoom(roomId);
      expect(room.guestUid, isNull);
      expect(room.kickedUids, [guest.uid]);
      expect((await getPlayerState(guest))?.roomId, isNull);
      await expectRejected(guest, 'joinRoom', {'roomId': roomId}, 'kicked');

      // 빈자리에 다음 사람이 같은 링크로 들어온다.
      expect(await callResult(third, 'joinRoom', {'roomId': roomId}), isNull);
      expect((await getRoom(roomId)).guestUid, third.uid);
    });

    test('상대가 나가면 빈자리가 되고 방장이 나가면 방이 닫힌다', () async {
      final host = await createPlayer();
      final guest = await createPlayer();
      final next = await createPlayer();
      final roomId = await createRoom(host, {'hostSide': 'cho', 'listed': false});
      await callResult(guest, 'joinRoom', {'roomId': roomId});

      expect(await callResult(guest, 'leaveRoom', {'roomId': roomId}), isNull);
      expect((await getRoom(roomId)).guestUid, isNull);
      expect((await getPlayerState(guest))?.roomId, isNull);
      // 나간 뒤 다시 나가도 그대로 성공한다.
      expect(await callResult(guest, 'leaveRoom', {'roomId': roomId}), isNull);

      await callResult(next, 'joinRoom', {'roomId': roomId});
      expect(await callResult(host, 'leaveRoom', {'roomId': roomId}), isNull);
      expect((await getRoom(roomId)).status, RoomStatus.closed);
      expect((await getPlayerState(host))?.roomId, isNull);
      expect((await getPlayerState(next))?.roomId, isNull);
      await expectRejected(guest, 'joinRoom', {'roomId': roomId}, 'roomClosed');
      await expectRejected(host, 'startRoomGame', {'roomId': roomId}, 'roomClosed');
      await expectRejected(guest, 'joinRoom', {'roomId': 'missingRoom000000000'}, 'notFound');
    });

    test('급수 범위 밖이면 들어오지 못한다', () async {
      final host = await createPlayer();
      final guest = await createPlayer();
      final roomId = await createRoom(host, {
        'hostSide': 'random',
        'listed': true,
        'rankRange': {'min': 5, 'max': 27},
      });
      expect((await getRoom(roomId)).rankRange?.min, 5);
      // 새 계정은 18급(rankLevel 1)이다.
      await expectRejected(guest, 'joinRoom', {'roomId': roomId}, 'rankOutOfRange');
    });

    test('잘못된 조건은 받지 않는다', () async {
      final host = await createPlayer();
      for (final options in [
        {
          'hostSide': 'cho',
          'listed': false,
          'rankRange': {'min': 1, 'max': 27},
        },
        {
          'hostSide': 'cho',
          'listed': true,
          'rankRange': {'min': 10, 'max': 5},
        },
        {'hostSide': 'black', 'listed': true},
        {
          'hostSide': 'cho',
          'listed': true,
          'handicap': {'remover': 'creator', 'pieces': <String>[]},
        },
        {
          'hostSide': 'cho',
          'listed': true,
          'handicap': {
            'remover': 'creator',
            'pieces': ['leftChariot', 'leftChariot'],
          },
        },
      ]) {
        final (status, body) = await callApi(client, httpServer.port, host, 'createRoom', options);
        expect(status, 400, reason: '$options: $body');
        expect((body['error'] as Map)['status'], 'INVALID_ARGUMENT');
      }
      expect((await getPlayerState(host))?.roomId, isNull);
    });

    test('이용 정지 중이면 방을 만들거나 들어가지 못한다', () async {
      final host = await createPlayer();
      final banned = await createPlayer();
      final roomId = await createRoom(host, {'hostSide': 'cho', 'listed': true});
      await server.firestore.commit([
        UpdateWrite('users_private/${banned.uid}', {
          'sanction': {'type': 'permanentBan', 'endsAt': null, 'reason': 'test'},
        }),
      ]);
      await expectRejected(banned, 'createRoom', {'hostSide': 'cho', 'listed': true}, 'sanctioned');
      await expectRejected(banned, 'joinRoom', {'roomId': roomId}, 'sanctioned');
    });

    test('방장이 시작한 대국이 끝나면 방은 기다리는 중으로 돌아가고 두 사람은 방에 남는다', () async {
      final host = await createPlayer();
      final guest = await createPlayer();
      final roomId = await createRoom(host, {'hostSide': 'cho', 'listed': false});
      await callResult(guest, 'joinRoom', {'roomId': roomId});

      final gameId = await startGame(host, roomId);
      // 두 번 눌러도 같은 대국이다.
      expect(await startGame(host, roomId), gameId);
      final room = await getRoom(roomId);
      expect(room.status, RoomStatus.playing);
      expect(room.gameId, gameId);
      final game = await getGame(gameId);
      expect(game.meta.mode, GameMode.room);
      expect(game.meta.rated, isFalse);
      expect(game.meta.listed, isFalse);
      expect(game.meta.roomId, roomId);
      expect(game.meta.handicap, isNull);
      expect(game.meta.players.cho.uid, host.uid);
      expect(game.meta.players.han.uid, guest.uid);
      for (final account in [host, guest]) {
        final state = await getPlayerState(account);
        expect(state?.gameId, gameId);
        expect(state?.roomId, roomId);
      }
      // 대국 중에는 나가거나 내보낼 수 없다.
      await expectRejected(guest, 'leaveRoom', {'roomId': roomId}, 'busy');
      await expectRejected(host, 'kickGuest', {'roomId': roomId}, 'busy');

      await finishByResignation(gameId, guest);
      expect((await getRoom(roomId)).status, RoomStatus.waiting);
      expect((await getRoom(roomId)).gameId, gameId);
      for (final account in [host, guest]) {
        final state = await getPlayerState(account);
        expect(state?.gameId, isNull);
        expect(state?.lastGameId, gameId);
        expect(state?.roomId, roomId);
      }
      expect(await server.repositories.ratings.getRating(host.uid), isNull);

      // 방장이 다시 시작할 수 있다.
      final secondId = await startGame(host, roomId);
      expect(secondId, isNot(gameId));
      expect((await getRoom(roomId)).gameId, secondId);
    });

    test('방 대국의 다시 두기는 초와 한을 바꾸고 방을 새 대국으로 바꾼다', () async {
      final host = await createPlayer();
      final guest = await createPlayer();
      final roomId = await createRoom(host, {'hostSide': 'han', 'listed': true});
      await callResult(guest, 'joinRoom', {'roomId': roomId});
      final gameId = await startGame(host, roomId);
      expect((await getGame(gameId)).meta.players.han.uid, host.uid);
      await finishByResignation(gameId, host);

      expect(await callResult(guest, 'requestRematch', {'gameId': gameId}), {'gameId': null});
      final rematchGameId = (await callResult(host, 'requestRematch', {'gameId': gameId}))?['gameId'] as String?;
      expect(rematchGameId, isNotNull);
      final rematch = await getGame(rematchGameId!);
      expect(rematch.meta.mode, GameMode.room);
      expect(rematch.meta.roomId, roomId);
      expect(rematch.meta.listed, isTrue);
      expect(rematch.meta.rematchOf, gameId);
      expect(rematch.meta.rematchCount, 1);
      expect(rematch.meta.players.cho.uid, host.uid);
      expect(rematch.meta.players.han.uid, guest.uid);
      final room = await getRoom(roomId);
      expect(room.status, RoomStatus.playing);
      expect(room.gameId, rematchGameId);
      for (final account in [host, guest]) {
        expect((await getPlayerState(account))?.gameId, rematchGameId);
      }

      // 방 대국은 횟수를 막지 않는다.
      await finishByResignation(rematchGameId, guest);
      await callResult(host, 'requestRematch', {'gameId': rematchGameId});
      final third = (await callResult(guest, 'requestRematch', {'gameId': rematchGameId}))?['gameId'] as String?;
      expect((await getGame(third!)).meta.rematchCount, 2);
    });

    test('상대가 방을 나갔으면 방 대국의 다시 두기를 만들지 않는다', () async {
      final host = await createPlayer();
      final guest = await createPlayer();
      final roomId = await createRoom(host, {'hostSide': 'cho', 'listed': false});
      await callResult(guest, 'joinRoom', {'roomId': roomId});
      final gameId = await startGame(host, roomId);
      await finishByResignation(gameId, guest);

      await callResult(host, 'requestRematch', {'gameId': gameId});
      await callResult(guest, 'leaveRoom', {'roomId': roomId});
      await expectRejected(guest, 'requestRematch', {'gameId': gameId}, 'rematchUnavailable');
      final rematch = (await getGame(gameId)).rematch;
      expect(rematch?.cancelled, isTrue);
      expect(rematch?.gameId, isNull);
      expect((await getRoom(roomId)).status, RoomStatus.waiting);
    });

    test('접장기 방은 떼는 쪽이 한이고 다시 두기에서도 한을 잡는다', () async {
      final host = await createPlayer();
      final guest = await createPlayer();
      final pieces = [HandicapPiece.leftChariot, HandicapPiece.rightCannon];
      final roomId = await createRoom(host, {
        'hostSide': 'cho',
        'listed': true,
        'handicap': {'remover': 'opponent', 'pieces': pieces.map((piece) => piece.name).toList()},
      });
      expect((await getRoom(roomId)).handicap?.remover, HandicapRemover.opponent);
      await callResult(guest, 'joinRoom', {'roomId': roomId});
      final gameId = await startGame(host, roomId);
      final game = await getGame(gameId);
      expect(game.meta.players.cho.uid, host.uid);
      expect(game.meta.players.han.uid, guest.uid);
      expect(game.meta.handicap, pieces);

      await finishByResignation(gameId, host);
      await callResult(host, 'requestRematch', {'gameId': gameId});
      final rematchGameId = (await callResult(guest, 'requestRematch', {'gameId': gameId}))?['gameId'] as String?;
      final rematch = await getGame(rematchGameId!);
      expect(rematch.meta.players.han.uid, guest.uid);
      expect(rematch.meta.handicap, pieces);

      // 방장이 떼는 방은 방장이 한이다.
      final other = await createPlayer();
      final otherGuest = await createPlayer();
      final otherRoomId = await createRoom(other, {
        'hostSide': 'cho',
        'listed': false,
        'handicap': {
          'remover': 'creator',
          'pieces': ['leftHorse'],
        },
      });
      await callResult(otherGuest, 'joinRoom', {'roomId': otherRoomId});
      final otherGameId = await startGame(other, otherRoomId);
      expect((await getGame(otherGameId)).meta.players.han.uid, other.uid);
    });

    test('상대의 연결이 오래 없으면 자리를 비우고 방장의 연결이 오래 없으면 방을 닫는다', () async {
      final host = await createPlayer();
      final guest = await createPlayer();
      final roomId = await createRoom(host, {'hostSide': 'cho', 'listed': false});
      await callResult(guest, 'joinRoom', {'roomId': roomId});

      await setConnection(guest, online: false);
      await waitFor(() async => (await getRoom(roomId)).guestUid == null ? true : null);
      expect((await getPlayerState(guest))?.roomId, isNull);
      expect((await getRoom(roomId)).status, RoomStatus.waiting);

      // 잠깐 끊겼다가 돌아오면 그대로 둔다.
      await setConnection(host, online: false);
      await waitFor(() async => (await getRoom(roomId)).hostAbsentSince);
      await setConnection(host);
      await waitFor(() async => (await getRoom(roomId)).hostAbsentSince == null ? true : null);
      expect((await getRoom(roomId)).status, RoomStatus.waiting);

      await setConnection(host, online: false);
      await waitFor(() async => (await getRoom(roomId)).status == RoomStatus.closed ? true : null);
      expect((await getPlayerState(host))?.roomId, isNull);
    });
  });
}
