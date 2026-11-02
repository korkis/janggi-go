@Tags(['emulator'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:janggigo_game/firebase/firestore_client.dart';
import 'package:janggigo_game/game_server.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/models/active_game.dart';
import 'package:janggigo_game/server_environment.dart';
import 'package:test/test.dart';

/// 서로 다른 두 계정으로 대국을 만들고 끝까지 두는 통합 테스트(`docs/server.md`의 개발 환경).
/// `server/game/README.md`의 "테스트"처럼 `firebase emulators:exec`로 실행하면 돈다.
///
/// 시간패와 상차림 마감까지 기다릴 수 있게 `devCreateGame`의 시간을 짧게 줄인다.
void main() {
  final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final skip = emulatorHost == null ? 'FIRESTORE_EMULATOR_HOST가 없습니다. firebase emulators:exec로 실행하세요' : false;

  group('한 판 두기', skip: skip, () {
    late GameServer server;
    late HttpServer httpServer;
    final client = http.Client();

    setUpAll(() async {
      server = GameServer.create(
        environment: ServerEnvironment.fromPlatform(),
        logger: GameLogger(format: LogFormat.text, minSeverity: LogSeverity.warning),
        devTimeControl: const TimeControl(
          baseMs: 1000,
          periodMs: 500,
          periods: 1,
          setupMs: 1000,
          extensionPeriods: 2,
          extensionLimit: 2,
        ),
        devMatchIntro: Duration.zero,
      );
      httpServer = await server.serve(port: 0);
      await _ensureAppConfig(server.firestore);
    });

    tearDownAll(() async {
      client.close();
      await server.close();
    });

    Future<Map<String, Object?>> callOk(_Account account, String api, Object? data) =>
        _callOk(client, httpServer.port, account, api, data);

    Future<void> expectRejected(_Account account, String api, Object? data, String code) =>
        _expectRejected(client, httpServer.port, account, api, data, code);

    Future<ActiveGame> getGame(String gameId) async => (await server.repositories.activeGames.getGame(gameId))!;

    Future<String> createGame(_Account cho, _Account han) => _createGame(client, httpServer.port, cho, han);

    test('상차림, 수, 한수쉼으로 끝내고 기보를 저장한다', () async {
      final cho = await _createAccount(client, server.firestore);
      final han = await _createAccount(client, server.firestore);

      await expectRejected(cho, 'devCreateGame', {'opponentNickname': 'zz${_randomId(6)}', 'side': 'cho'}, 'notFound');
      final gameId = await createGame(cho, han);

      var game = await getGame(gameId);
      expect(game.meta.players.cho.uid, cho.uid);
      expect(game.meta.players.han.nickname, han.nickname);
      expect((await server.repositories.playerStates.getPlayerState(cho.uid))?.gameId, gameId);
      expect((await server.repositories.playerStates.getPlayerState(han.uid))?.gameId, gameId);

      // 이미 대국 중이면 새 대국을 만들 수 없다.
      await expectRejected(han, 'devCreateGame', {'opponentNickname': cho.nickname, 'side': 'random'}, 'busy');

      // 한이 먼저 고른다. 초는 아직 고를 수 없다.
      await expectRejected(cho, 'setFormation', {
        'gameId': gameId,
        'formation': 'horseElephantElephantHorse',
        'confirmed': true,
      }, 'notYourTurn');
      await callOk(han, 'setFormation', {
        'gameId': gameId,
        'formation': 'elephantHorseHorseElephant',
        'confirmed': false,
      });
      expect(
        (await server.repositories.playerStates.getPlayerState(han.uid))?.setupDraft?.formation.name,
        'elephantHorseHorseElephant',
      );
      await callOk(han, 'setFormation', {
        'gameId': gameId,
        'formation': 'elephantHorseHorseElephant',
        'confirmed': true,
      });
      await callOk(cho, 'setFormation', {
        'gameId': gameId,
        'formation': 'horseElephantElephantHorse',
        'confirmed': true,
      });
      game = await getGame(gameId);
      expect(game.state.phase.name, 'playing');
      expect(game.state.setup.han?.name, 'elephantHorseHorseElephant');

      await expectRejected(han, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'a7b7'}, 'notYourTurn');
      await expectRejected(cho, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'a1a9'}, 'illegalMove');
      await callOk(cho, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'a4b4'});
      // 응답을 못 받고 다시 보낸 같은 수는 성공으로 본다.
      await callOk(cho, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'a4b4'});
      await expectRejected(han, 'playMove', {'gameId': gameId, 'moveIndex': 0, 'move': 'a7b7'}, 'moveConflict');
      final outsider = await _createAccount(client, server.firestore);
      await expectRejected(outsider, 'playMove', {'gameId': gameId, 'moveIndex': 1, 'move': 'pass'}, 'notPlayer');

      await callOk(han, 'playMove', {'gameId': gameId, 'moveIndex': 1, 'move': 'pass'});
      await callOk(cho, 'playMove', {'gameId': gameId, 'moveIndex': 2, 'move': 'pass'});

      game = await getGame(gameId);
      expect(game.state.phase.name, 'finished');
      expect(game.state.result?.reason.name, 'consecutivePasses');
      expect(game.moves.map((move) => move.m), ['a4b4', 'pass', 'pass']);
      await expectRejected(han, 'resign', {'gameId': gameId}, 'gameOver');

      // 끝나면 finalizeGame이 바로 한 번 돈다.
      final archived = await server.firestore.getDocument('games_archived/$gameId');
      expect(archived?['playerUids'], [cho.uid, han.uid]);
      expect(archived?['moves'], ['a4b4', 'pass', 'pass']);
      expect((archived?['result'] as Map)['reason'], 'consecutivePasses');
      expect(archived?['mode'], 'challenge');
      expect(archived?['rated'], false);
      final choState = await server.repositories.playerStates.getPlayerState(cho.uid);
      expect(choState?.gameId, isNull);
      expect(choState?.lastGameId, gameId);
      expect((await server.repositories.playerStates.getPlayerState(han.uid))?.setupDraft, isNull);

      // 대국에서 풀렸으므로 다시 만들 수 있다.
      final secondGameId = await createGame(han, cho);
      await callOk(cho, 'resign', {'gameId': secondGameId});
      final second = await getGame(secondGameId);
      expect(second.state.result?.reason.name, 'resignation');
      expect(second.state.result?.winner.name, 'cho');
    });

    test('상차림 마감과 시간패를 예약 작업이 판정한다', () async {
      final cho = await _createAccount(client, server.firestore);
      final han = await _createAccount(client, server.firestore);
      final gameId = await createGame(cho, han);
      await callOk(han, 'setFormation', {
        'gameId': gameId,
        'formation': 'horseElephantElephantHorse',
        'confirmed': false,
      });

      // 한 1초, 초 1초 상차림 마감 뒤 초 차례에서 기본 1초 + 초읽기 0.5초 × 2가 지나면 초가 시간패로 진다.
      final game = await _waitFor(() async {
        final game = await getGame(gameId);
        return game.state.phase.name == 'finished' ? game : null;
      }, timeout: const Duration(seconds: 15));
      expect(game.state.setup.han?.name, 'horseElephantElephantHorse');
      expect(game.state.setup.cho?.name, 'horseElephantHorseElephant');
      expect(game.state.result?.reason.name, 'timeout');
      expect(game.state.result?.winner.name, 'han');
      expect(game.state.endedAt, game.state.turnStartedAt! + 1000 + 2 * 500);

      final archived = await _waitFor(() => server.firestore.getDocument('games_archived/$gameId'));
      expect((archived['result'] as Map)['reason'], 'timeout');
      expect((await server.repositories.playerStates.getPlayerState(cho.uid))?.gameId, isNull);
    });
  });

  // 접속 끊김(`docs/server.md`의 접속 끊김). 앱 대신 테스트가 `connections`를 직접 쓴다. 시계와 상차림은 길게, 끊김 허용
  // 시간은 짧게 둔다.
  group('접속 끊김', skip: skip, () {
    const limitMs = 2000;
    late GameServer server;
    late HttpServer httpServer;
    final client = http.Client();

    setUpAll(() async {
      server = GameServer.create(
        environment: ServerEnvironment.fromPlatform(),
        logger: GameLogger(format: LogFormat.text, minSeverity: LogSeverity.warning),
        devTimeControl: const TimeControl(
          baseMs: 60000,
          periodMs: 30000,
          periods: 3,
          setupMs: 60000,
          extensionPeriods: 2,
          extensionLimit: 2,
        ),
        devMatchIntro: Duration.zero,
        devDisconnectLimit: const Duration(milliseconds: limitMs),
      );
      httpServer = await server.serve(port: 0);
      await _ensureAppConfig(server.firestore);
    });

    tearDownAll(() async {
      client.close();
      await server.close();
    });

    Future<ActiveGame> getGame(String gameId) async => (await server.repositories.activeGames.getGame(gameId))!;

    Future<void> setConnection(
      _Account account, {
      required bool online,
      required int activeSince,
      required int lastSeenAt,
    }) {
      return server.rtdb.put('connections/${account.uid}/c1', {
        'online': online,
        'foreground': true,
        'activeSince': activeSince,
        'lastSeenAt': lastSeenAt,
      });
    }

    Future<void> checkGame(_Account account, String gameId) async {
      await _callOk(client, httpServer.port, account, 'checkGame', {'gameId': gameId});
    }

    int nowMs() => DateTime.now().millisecondsSinceEpoch;

    test('한 대국 동안 끊긴 시간을 모두 더해 허용 시간에 닿으면 끊긴 쪽이 진다', () async {
      final cho = await _createAccount(client, server.firestore);
      final han = await _createAccount(client, server.firestore);
      final outsider = await _createAccount(client, server.firestore);
      final connectedAt = nowMs();
      await setConnection(cho, online: true, activeSince: connectedAt, lastSeenAt: connectedAt);
      await setConnection(han, online: true, activeSince: connectedAt, lastSeenAt: connectedAt);
      final gameId = await _createGame(client, httpServer.port, cho, han);

      await _expectRejected(client, httpServer.port, outsider, 'checkGame', {'gameId': gameId}, 'notPlayer');
      await checkGame(cho, gameId);
      var game = await getGame(gameId);
      expect(game.meta.disconnectLimitMs, limitMs);
      expect(game.state.disconnect.han.since, isNull);

      // 한이 끊기고 초의 앱이 그것을 보고 부른다.
      final firstSince = nowMs();
      await setConnection(han, online: false, activeSince: connectedAt, lastSeenAt: firstSince);
      await checkGame(cho, gameId);
      game = await getGame(gameId);
      expect(game.state.disconnect.han.since, firstSince);
      expect(game.state.disconnect.cho.since, isNull);

      // 0.5초 뒤 돌아온 앱이 부른다. 끊긴 시간을 합계에 더한다.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final backAt = nowMs();
      await setConnection(han, online: true, activeSince: backAt, lastSeenAt: backAt);
      await checkGame(han, gameId);
      game = await getGame(gameId);
      expect(game.state.disconnect.han.since, isNull);
      expect(game.state.disconnect.han.usedMs, backAt - firstSince);

      // 다시 끊기면 남은 허용 시간이 지난 때 예약 작업이 끝낸다.
      final secondSince = nowMs();
      await setConnection(han, online: false, activeSince: backAt, lastSeenAt: secondSince);
      await checkGame(cho, gameId);
      final ended = await _waitFor(() async {
        final game = await getGame(gameId);
        return game.state.phase.name == 'finished' ? game : null;
      });
      expect(ended.state.result?.reason.name, 'disconnect');
      expect(ended.state.result?.winner.name, 'cho');
      expect(ended.state.endedAt, secondSince + limitMs - (backAt - firstSince));

      // 끝난 대국은 아무것도 하지 않고 성공한다.
      await checkGame(han, gameId);
      final archived = await _waitFor(() => server.firestore.getDocument('games_archived/$gameId'));
      expect((archived['result'] as Map)['reason'], 'disconnect');
    });

    test('끊긴 쪽은 상대의 수에서도 판정한다', () async {
      final cho = await _createAccount(client, server.firestore);
      final han = await _createAccount(client, server.firestore);
      final connectedAt = nowMs();
      await setConnection(cho, online: true, activeSince: connectedAt, lastSeenAt: connectedAt);
      await setConnection(han, online: true, activeSince: connectedAt, lastSeenAt: connectedAt);
      final gameId = await _createGame(client, httpServer.port, cho, han);

      // 초가 끊긴 채로 한이 상차림을 정하면 그 요청에서 초의 끊김을 기록한다.
      final since = nowMs();
      await setConnection(cho, online: false, activeSince: connectedAt, lastSeenAt: since);
      await _callOk(client, httpServer.port, han, 'setFormation', {
        'gameId': gameId,
        'formation': 'horseElephantHorseElephant',
        'confirmed': true,
      });
      final game = await getGame(gameId);
      expect(game.state.setup.han?.name, 'horseElephantHorseElephant');
      expect(game.state.disconnect.cho.since, since);
    });
  });
}

class _Account {
  final String uid;
  final String idToken;
  final String nickname;

  const _Account({required this.uid, required this.idToken, required this.nickname});
}

/// Auth 에뮬레이터 계정과 프로필. 프로필은 Functions가 만들지만 여기서는 테스트 준비로 직접 쓴다.
Future<_Account> _createAccount(http.Client client, FirestoreClient firestore) async {
  final authHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] ?? '127.0.0.1:${EmulatorPorts.auth}';
  final response = await client.post(
    Uri.parse('http://$authHost/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': '${_randomId(20)}@example.com', 'password': 'password123', 'returnSecureToken': true}),
  );
  if (response.statusCode != 200) {
    throw StateError('Auth 에뮬레이터 가입 실패: ${response.statusCode} ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, Object?>;
  final uid = body['localId'] as String;
  final nickname = 't${_randomId(8)}';
  final now = DateTime.now().toUtc();
  await firestore.commit([
    CreateWrite('users/$uid', {
      'nickname': nickname,
      'rankLevel': 1,
      'stats': {'games': 0, 'wins': 0, 'losses': 0},
      'createdAt': now,
    }),
    CreateWrite('nicknames/$nickname', {'uid': uid, 'createdAt': now}),
  ]);
  return _Account(uid: uid, idToken: body['idToken'] as String, nickname: nickname);
}

Future<(int, Map<String, Object?>)> _call(
  http.Client client,
  int port,
  _Account account,
  String api,
  Object? data,
) async {
  final response = await client.post(
    Uri.parse('http://127.0.0.1:$port/$api'),
    headers: {'Authorization': 'Bearer ${account.idToken}', 'Content-Type': 'application/json'},
    body: jsonEncode({'data': data}),
  );
  return (response.statusCode, jsonDecode(response.body) as Map<String, Object?>);
}

Future<Map<String, Object?>> _callOk(http.Client client, int port, _Account account, String api, Object? data) async {
  final (status, body) = await _call(client, port, account, api, data);
  expect(status, 200, reason: '$api: $body');
  return body;
}

Future<void> _expectRejected(
  http.Client client,
  int port,
  _Account account,
  String api,
  Object? data,
  String code,
) async {
  final (status, body) = await _call(client, port, account, api, data);
  expect(status, 400, reason: '$api: $body');
  expect(((body['error'] as Map)['details'] as Map)['code'], code);
}

/// [cho]가 [han]과의 개발용 대국을 만든다.
Future<String> _createGame(http.Client client, int port, _Account cho, _Account han) async {
  final body = await _callOk(client, port, cho, 'devCreateGame', {'opponentNickname': han.nickname, 'side': 'cho'});
  return (body['result'] as Map)['gameId'] as String;
}

/// `configs/app`이 없으면 처음 값으로 만든다. 다른 테스트나 앱이 같은 에뮬레이터를 쓰고 있으면 그대로 둔다.
Future<void> _ensureAppConfig(FirestoreClient firestore) async {
  try {
    await firestore.commit([
      CreateWrite('configs/app', {
        'disconnectLimitSeconds': 30,
        'quickRematchLimit': 5,
        'onlineUsersVisible': false,
        'autoSanctionEnabled': false,
        'heartbeatSeconds': 5,
      }),
    ]);
  } on FirestoreException catch (error) {
    if (error.status != 'ALREADY_EXISTS') {
      rethrow;
    }
  }
}

/// [read]가 null이 아닌 값을 돌려줄 때까지 다시 읽는다.
Future<T> _waitFor<T extends Object>(
  Future<T?> Function() read, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final value = await read();
    if (value != null) {
      return value;
    }
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('기다리던 값이 오지 않았습니다', timeout);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

String _randomId(int length) {
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(length, (_) => characters[random.nextInt(characters.length)]).join();
}
