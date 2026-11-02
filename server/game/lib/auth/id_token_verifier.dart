import '../clock.dart';
import 'jwt.dart';
import 'public_keys.dart';

/// 검사를 통과한 Firebase ID token.
class VerifiedIdToken {
  final String uid;
  final Map<String, Object?> claims;

  const VerifiedIdToken({required this.uid, required this.claims});
}

/// 앱이 보낸 Firebase ID token을 검사한다(`docs/server.md`의 호출 방식).
///
/// Firebase Admin SDK의 `verifyIdToken`과 같은 기준이다. 운영에서는 Google 공개 키로 RS256 서명을 확인하고,
/// 에뮬레이터에서는 Auth 에뮬레이터가 서명 없이 만든 토큰을 받으므로 서명은 보지 않고 클레임만 확인한다.
class FirebaseIdTokenVerifier {
  final String projectId;

  /// 서명을 검사할 키. null이면 에뮬레이터 토큰으로 보고 서명을 검사하지 않는다.
  final PublicKeySource? keySource;
  final Clock clock;

  const FirebaseIdTokenVerifier.production({
    required this.projectId,
    required PublicKeySource this.keySource,
    this.clock = utcNow,
  });

  const FirebaseIdTokenVerifier.emulator({required this.projectId, this.clock = utcNow}) : keySource = null;

  /// [token]을 검사한다. 통과하지 못하면 [AuthException]을 던진다.
  Future<VerifiedIdToken> verify(String token) async {
    final jwt = Jwt.parse(token);
    final keySource = this.keySource;
    if (keySource != null) {
      await _verifySignature(jwt, keySource);
    }
    _verifyClaims(jwt);
    return VerifiedIdToken(uid: jwt.getString('sub')!, claims: jwt.payload);
  }

  Future<void> _verifySignature(Jwt jwt, PublicKeySource keySource) async {
    if (jwt.algorithm != 'RS256') {
      throw AuthException('지원하지 않는 서명 방식입니다: ${jwt.algorithm}');
    }
    final keyId = jwt.keyId;
    if (keyId == null) {
      throw const AuthException('kid가 없습니다');
    }
    final key = await keySource.getKey(keyId);
    if (key == null) {
      throw AuthException('모르는 kid입니다: $keyId');
    }
    if (!jwt.isSignedBy(key)) {
      throw const AuthException('서명이 맞지 않습니다');
    }
  }

  void _verifyClaims(Jwt jwt) {
    final now = clock();
    if (jwt.payload['aud'] != projectId) {
      throw const AuthException('aud가 프로젝트와 다릅니다');
    }
    if (jwt.getString('iss') != 'https://securetoken.google.com/$projectId') {
      throw const AuthException('iss가 프로젝트와 다릅니다');
    }
    final subject = jwt.getString('sub');
    if (subject == null || subject.isEmpty || subject.length > 128) {
      throw const AuthException('sub가 올바르지 않습니다');
    }
    final expiresAt = jwt.getTime('exp');
    if (expiresAt == null || !now.isBefore(expiresAt)) {
      throw const AuthException('만료된 토큰입니다');
    }
    _verifyNotInFuture(jwt, 'iat', now);
    _verifyNotInFuture(jwt, 'auth_time', now);
  }

  void _verifyNotInFuture(Jwt jwt, String claim, DateTime now) {
    final time = jwt.getTime(claim);
    if (time == null || time.isAfter(now.add(allowedClockSkew))) {
      throw AuthException('$claim이 올바르지 않습니다');
    }
  }
}

/// 토큰 발급 서버와 대국 서버의 시계 차이로 iat가 조금 앞설 수 있다.
const allowedClockSkew = Duration(minutes: 5);
