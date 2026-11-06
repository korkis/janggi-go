import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:janggigo_game/firebase/firestore_client.dart';
import 'package:janggigo_game/server_environment.dart';
import 'package:test/test.dart';

// 에뮬레이터 통합 테스트(`test/emulator/`)가 같이 쓰는 준비와 호출이다.

class EmulatorAccount {
  final String uid;
  final String idToken;
  final String nickname;

  const EmulatorAccount({required this.uid, required this.idToken, required this.nickname});
}

/// Auth 에뮬레이터 계정과 프로필(`users`, `users_private`, `nicknames`, `coin_wallets`). 프로필은 Functions가 만들지만 여기서는 테스트
/// 준비로 Functions의 `createProfile`과 같은 처음 값을 직접 쓴다.
Future<EmulatorAccount> createEmulatorAccount(http.Client client, FirestoreClient firestore) async {
  final authHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] ?? '127.0.0.1:${EmulatorPorts.auth}';
  final response = await client.post(
    Uri.parse('http://$authHost/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': '${randomId(20)}@example.com', 'password': 'password123', 'returnSecureToken': true}),
  );
  if (response.statusCode != 200) {
    throw StateError('Auth 에뮬레이터 가입 실패: ${response.statusCode} ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, Object?>;
  final uid = body['localId'] as String;
  final nickname = 't${randomId(8)}';
  final now = DateTime.now().toUtc();
  await firestore.commit([
    CreateWrite('users/$uid', {
      'nickname': nickname,
      'rankLevel': 1,
      'stats': {'games': 0, 'wins': 0, 'losses': 0},
      'createdAt': now,
    }),
    CreateWrite('users_private/$uid', {
      'challengesEnabled': true,
      'rankProgress': 0,
      'winsToNextRank': null,
      'nicknameChangeCount': 0,
      'nicknameChangedAt': null,
      'sanction': null,
    }),
    CreateWrite('nicknames/$nickname', {'uid': uid, 'createdAt': now}),
    CreateWrite('coin_wallets/$uid', {
      'freeCoins': 300,
      'paidCoins': 0,
      'balance': 300,
      'attendanceDay': null,
      'attendanceStreak': 0,
      'updatedAt': now,
    }),
  ]);
  return EmulatorAccount(uid: uid, idToken: body['idToken'] as String, nickname: nickname);
}

/// [account]로 대국 서버의 [api]를 부른다. HTTP 상태와 응답 본문을 돌려준다.
Future<(int, Map<String, Object?>)> callApi(
  http.Client client,
  int port,
  EmulatorAccount account,
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

Future<Map<String, Object?>> callApiOk(
  http.Client client,
  int port,
  EmulatorAccount account,
  String api,
  Object? data,
) async {
  final (status, body) = await callApi(client, port, account, api, data);
  expect(status, 200, reason: '$api: $body');
  return body;
}

Future<void> expectApiRejected(
  http.Client client,
  int port,
  EmulatorAccount account,
  String api,
  Object? data,
  String code,
) async {
  final (status, body) = await callApi(client, port, account, api, data);
  expect(status, 400, reason: '$api: $body');
  expect(((body['error'] as Map)['details'] as Map)['code'], code);
}

/// [cho]가 [han]과의 개발용 대국을 만든다.
Future<String> createDevGame(http.Client client, int port, EmulatorAccount cho, EmulatorAccount han) async {
  final body = await callApiOk(client, port, cho, 'devCreateGame', {'opponentNickname': han.nickname, 'side': 'cho'});
  return (body['result'] as Map)['gameId'] as String;
}

/// `configs/app`이 없으면 처음 값으로 만든다. 다른 테스트나 앱이 같은 에뮬레이터를 쓰고 있으면 그대로 둔다.
Future<void> ensureAppConfig(FirestoreClient firestore) async {
  try {
    await firestore.commit([
      CreateWrite('configs/app', {
        'disconnectLimitSeconds': 30,
        'quickRematchLimit': 5,
        'onlineUsersVisible': false,
        'autoSanctionEnabled': false,
        'heartbeatSeconds': 5,
        'entryFeeEnabled': true,
        'coinSignupBonus': 300,
        'coinEntryFee': 10,
        'coinWinReward': 12,
        'coinLossReward': 0,
        'coinAttendanceReward': 30,
        'coinAttendanceStreakReward': 100,
        'coinNicknameChangeCost': 300,
      }),
    ]);
  } on FirestoreException catch (error) {
    if (error.status != 'ALREADY_EXISTS') {
      rethrow;
    }
  }
}

/// [read]가 null이 아닌 값을 돌려줄 때까지 다시 읽는다.
Future<T> waitFor<T extends Object>(
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

String randomId(int length) {
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(length, (_) => characters[random.nextInt(characters.length)]).join();
}
