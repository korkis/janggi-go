import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 토큰이 없거나, 모양이 틀렸거나, 서명·클레임 검사를 통과하지 못했다.
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// 서명을 검사하기 전의 JWT. [parse]는 모양만 확인한다.
class Jwt {
  final Map<String, Object?> header;
  final Map<String, Object?> payload;

  /// 서명한 원문(`header.payload`).
  final String signingInput;
  final Uint8List signature;

  const Jwt({required this.header, required this.payload, required this.signingInput, required this.signature});

  /// `header.payload.signature` 모양의 토큰을 읽는다. 서명이 없는 토큰(Auth 에뮬레이터)은 [signature]가 비어 있다.
  factory Jwt.parse(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const AuthException('JWT 모양이 아닙니다');
    }
    try {
      return Jwt(
        header: _decodeJsonPart(parts[0]),
        payload: _decodeJsonPart(parts[1]),
        signingInput: '${parts[0]}.${parts[1]}',
        signature: decodeBase64Url(parts[2]),
      );
    } on FormatException {
      throw const AuthException('JWT를 읽을 수 없습니다');
    }
  }

  String? get algorithm => _stringOrNull(header['alg']);

  String? get keyId => _stringOrNull(header['kid']);

  /// RS256 서명을 [key]로 검사한다.
  bool isSignedBy(RSAPublicKey key) {
    final signer = RSASigner(SHA256Digest(), _sha256DigestInfoPrefix)
      ..init(false, PublicKeyParameter<RSAPublicKey>(key));
    try {
      return signer.verifySignature(Uint8List.fromList(utf8.encode(signingInput)), RSASignature(signature));
    } on ArgumentError {
      return false;
    }
  }

  /// 초 단위 숫자 클레임을 UTC 시각으로 읽는다. 없거나 숫자가 아니면 null.
  DateTime? getTime(String claim) {
    final value = payload[claim];
    if (value is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch((value * 1000).round(), isUtc: true);
  }

  String? getString(String claim) => _stringOrNull(payload[claim]);

  static Map<String, Object?> _decodeJsonPart(String part) {
    final decoded = jsonDecode(utf8.decode(decodeBase64Url(part)));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('JWT 부분이 JSON 객체가 아닙니다');
    }
    return decoded;
  }

  static String? _stringOrNull(Object? value) => value is String ? value : null;

  // PKCS#1 v1.5 서명의 SHA-256 DigestInfo 식별자.
  static const _sha256DigestInfoPrefix = '0609608648016503040201';
}

/// 패딩 없는 base64url을 읽는다.
Uint8List decodeBase64Url(String value) => base64Url.decode(base64Url.normalize(value));

/// 부호 없는 큰 정수 바이트열(JWK의 `n`, `e`)을 [BigInt]로 바꾼다.
BigInt decodeUnsignedBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}
