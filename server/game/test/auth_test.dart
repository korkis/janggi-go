import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:janggigo_game/auth/id_token_verifier.dart';
import 'package:janggigo_game/auth/jwt.dart';
import 'package:janggigo_game/auth/public_keys.dart';
import 'package:janggigo_game/auth/task_request_verifier.dart';
import 'package:test/test.dart';

import 'support/jwt_helpers.dart';

void main() {
  const projectId = 'janggi-go';
  final now = DateTime.utc(2026, 11, 2, 12);
  late TestKeyPair key;
  late TestKeyPair otherKey;

  setUpAll(() {
    key = TestKeyPair.generate('key-1');
    otherKey = TestKeyPair.generate('key-2');
  });

  Map<String, Object?> idTokenClaims({String uid = 'user-1'}) => {
    'iss': 'https://securetoken.google.com/$projectId',
    'aud': projectId,
    'sub': uid,
    'user_id': uid,
    'iat': toSeconds(now.subtract(const Duration(minutes: 1))),
    'auth_time': toSeconds(now.subtract(const Duration(minutes: 1))),
    'exp': toSeconds(now.add(const Duration(minutes: 59))),
  };

  group('FirebaseIdTokenVerifier.production', () {
    late FirebaseIdTokenVerifier verifier;

    setUp(() {
      verifier = FirebaseIdTokenVerifier.production(
        projectId: projectId,
        keySource: FixedKeySource({key.keyId: key.publicKey}),
        clock: () => now,
      );
    });

    test('서명과 클레임이 맞으면 uid를 돌려준다', () async {
      final verified = await verifier.verify(key.sign(idTokenClaims()));
      expect(verified.uid, 'user-1');
    });

    test('다른 키로 서명한 토큰은 거절한다', () async {
      final token = otherKey.sign(idTokenClaims(), keyId: key.keyId);
      await expectLater(verifier.verify(token), throwsA(isA<AuthException>()));
    });

    test('모르는 kid는 거절한다', () async {
      await expectLater(verifier.verify(otherKey.sign(idTokenClaims())), throwsA(isA<AuthException>()));
    });

    test('서명 없는 토큰은 거절한다', () async {
      await expectLater(verifier.verify(createUnsignedToken(idTokenClaims())), throwsA(isA<AuthException>()));
    });

    test('본문을 바꾼 토큰은 거절한다', () async {
      final parts = key.sign(idTokenClaims()).split('.');
      final forged = encodeBase64Url(utf8.encode(jsonEncode(idTokenClaims(uid: 'attacker'))));
      await expectLater(verifier.verify('${parts[0]}.$forged.${parts[2]}'), throwsA(isA<AuthException>()));
    });

    test('aud와 iss가 다른 프로젝트면 거절한다', () async {
      final otherAudience = {...idTokenClaims(), 'aud': 'other-project'};
      final otherIssuer = {...idTokenClaims(), 'iss': 'https://securetoken.google.com/other-project'};
      await expectLater(verifier.verify(key.sign(otherAudience)), throwsA(isA<AuthException>()));
      await expectLater(verifier.verify(key.sign(otherIssuer)), throwsA(isA<AuthException>()));
    });

    test('만료된 토큰은 거절한다', () async {
      final expired = {...idTokenClaims(), 'exp': toSeconds(now)};
      await expectLater(verifier.verify(key.sign(expired)), throwsA(isA<AuthException>()));
    });

    test('iat가 미래면 거절한다', () async {
      final future = {...idTokenClaims(), 'iat': toSeconds(now.add(const Duration(minutes: 10)))};
      await expectLater(verifier.verify(key.sign(future)), throwsA(isA<AuthException>()));
    });

    test('JWT 모양이 아니면 거절한다', () async {
      await expectLater(verifier.verify('not-a-token'), throwsA(isA<AuthException>()));
    });
  });

  group('FirebaseIdTokenVerifier.emulator', () {
    final verifier = FirebaseIdTokenVerifier.emulator(projectId: 'demo-janggi-go', clock: () => now);

    Map<String, Object?> emulatorClaims() => {
      ...idTokenClaims(),
      'iss': 'https://securetoken.google.com/demo-janggi-go',
      'aud': 'demo-janggi-go',
    };

    test('Auth 에뮬레이터의 서명 없는 토큰을 받는다', () async {
      final verified = await verifier.verify(createUnsignedToken(emulatorClaims()));
      expect(verified.uid, 'user-1');
    });

    test('서명이 없어도 클레임은 확인한다', () async {
      final otherProject = {...emulatorClaims(), 'aud': 'janggi-go'};
      await expectLater(verifier.verify(createUnsignedToken(otherProject)), throwsA(isA<AuthException>()));
    });
  });

  group('CloudTasksOidcVerifier', () {
    const audience = 'https://game-abc-du.a.run.app';
    const serviceAccount = 'game-tasks@janggi-go.iam.gserviceaccount.com';
    late CloudTasksOidcVerifier verifier;

    Map<String, Object?> oidcClaims() => {
      'iss': 'https://accounts.google.com',
      'aud': audience,
      'email': serviceAccount,
      'email_verified': true,
      'sub': '1234567890',
      'iat': toSeconds(now.subtract(const Duration(seconds: 5))),
      'exp': toSeconds(now.add(const Duration(minutes: 55))),
    };

    setUp(() {
      verifier = CloudTasksOidcVerifier(
        audience: audience,
        serviceAccountEmail: serviceAccount,
        keySource: FixedKeySource({key.keyId: key.publicKey}),
        clock: () => now,
      );
    });

    test('예약 작업 서비스 계정의 토큰을 받는다', () async {
      await verifier.verify(key.sign(oidcClaims()));
    });

    test('다른 서비스 계정이나 audience는 거절한다', () async {
      final otherAccount = {...oidcClaims(), 'email': 'someone@example.com'};
      final otherAudience = {...oidcClaims(), 'aud': 'https://other.run.app'};
      await expectLater(verifier.verify(key.sign(otherAccount)), throwsA(isA<AuthException>()));
      await expectLater(verifier.verify(key.sign(otherAudience)), throwsA(isA<AuthException>()));
    });

    test('Firebase ID token은 거절한다', () async {
      await expectLater(verifier.verify(key.sign(idTokenClaims())), throwsA(isA<AuthException>()));
    });
  });

  group('LocalTaskVerifier', () {
    test('같은 secret만 받는다', () async {
      final verifier = LocalTaskVerifier.random();
      await verifier.verify(verifier.secret);
      await expectLater(verifier.verify('${verifier.secret}x'), throwsA(isA<AuthException>()));
      await expectLater(LocalTaskVerifier.random().verify(verifier.secret), throwsA(isA<AuthException>()));
    });
  });

  group('GoogleJwkKeySource', () {
    test('JWK를 받아 max-age 동안 캐시한다', () async {
      var fetchCount = 0;
      final client = MockClient((request) async {
        fetchCount++;
        return http.Response(
          jsonEncode({
            'keys': [key.toJwk()],
          }),
          200,
          headers: {'cache-control': 'public, max-age=3600'},
        );
      });
      var current = now;
      final source = GoogleJwkKeySource(
        url: GoogleJwkKeySource.firebaseIdTokenKeysUrl,
        httpClient: client,
        clock: () => current,
      );

      final fetched = await source.getKey(key.keyId);
      expect(fetched?.modulus, key.publicKey.modulus);
      await source.getKey(key.keyId);
      expect(fetchCount, 1);

      current = now.add(const Duration(hours: 1));
      await source.getKey(key.keyId);
      expect(fetchCount, 2);
    });

    test('받은 키로 서명을 검사할 수 있다', () async {
      final keys = parseJwks({
        'keys': [key.toJwk()],
      });
      final verifier = FirebaseIdTokenVerifier.production(
        projectId: projectId,
        keySource: FixedKeySource(keys),
        clock: () => now,
      );
      expect((await verifier.verify(key.sign(idTokenClaims()))).uid, 'user-1');
    });
  });
}
