import 'dart:convert';
import 'dart:math';

import '../clock.dart';
import 'id_token_verifier.dart';
import 'jwt.dart';
import 'public_keys.dart';

/// 예약 작업 경로(`/tasks/...`)를 부른 쪽이 예약한 쪽인지 확인한다.
abstract interface class TaskRequestVerifier {
  /// `Authorization: Bearer <token>`의 [token]을 검사한다. 통과하지 못하면 [AuthException]을 던진다.
  Future<void> verify(String token);
}

/// 운영: Cloud Tasks가 붙인 Google OIDC 토큰만 받는다(`docs/server.md`의 호출 방식).
class CloudTasksOidcVerifier implements TaskRequestVerifier {
  /// 예약할 때 정한 audience. 대국 서버 주소다.
  final String audience;

  /// 예약 작업의 토큰을 만드는 서비스 계정.
  final String serviceAccountEmail;
  final PublicKeySource keySource;
  final Clock clock;

  const CloudTasksOidcVerifier({
    required this.audience,
    required this.serviceAccountEmail,
    required this.keySource,
    this.clock = utcNow,
  });

  @override
  Future<void> verify(String token) async {
    final jwt = Jwt.parse(token);
    if (jwt.algorithm != 'RS256') {
      throw AuthException('지원하지 않는 서명 방식입니다: ${jwt.algorithm}');
    }
    final keyId = jwt.keyId;
    if (keyId == null) {
      throw const AuthException('kid가 없습니다');
    }
    final key = await keySource.getKey(keyId);
    if (key == null || !jwt.isSignedBy(key)) {
      throw const AuthException('서명이 맞지 않습니다');
    }
    final now = clock();
    if (!_issuers.contains(jwt.getString('iss'))) {
      throw const AuthException('iss가 Google이 아닙니다');
    }
    if (jwt.payload['aud'] != audience) {
      throw const AuthException('aud가 대국 서버 주소와 다릅니다');
    }
    if (jwt.getString('email') != serviceAccountEmail || jwt.payload['email_verified'] != true) {
      throw const AuthException('예약 작업 서비스 계정이 아닙니다');
    }
    final expiresAt = jwt.getTime('exp');
    if (expiresAt == null || !now.isBefore(expiresAt)) {
      throw const AuthException('만료된 토큰입니다');
    }
    final issuedAt = jwt.getTime('iat');
    if (issuedAt == null || issuedAt.isAfter(now.add(allowedClockSkew))) {
      throw const AuthException('iat가 올바르지 않습니다');
    }
  }

  static const _issuers = {'https://accounts.google.com', 'accounts.google.com'};
}

/// 에뮬레이터: 같은 프로세스의 `LocalTaskScheduler`만 아는 임의 문자열을 받는다.
class LocalTaskVerifier implements TaskRequestVerifier {
  /// `LocalTaskScheduler`가 `Authorization`에 넣는 값. 프로세스를 켤 때마다 새로 만든다.
  final String secret;

  LocalTaskVerifier({required this.secret});

  /// 추측할 수 없는 [secret]으로 만든다.
  factory LocalTaskVerifier.random() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return LocalTaskVerifier(secret: base64Url.encode(bytes));
  }

  @override
  Future<void> verify(String token) async {
    if (!_isEqualInConstantTime(token, secret)) {
      throw const AuthException('예약 작업 토큰이 아닙니다');
    }
  }

  static bool _isEqualInConstantTime(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }
}
