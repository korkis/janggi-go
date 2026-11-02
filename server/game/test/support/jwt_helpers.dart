import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:janggigo_game/auth/public_keys.dart';
import 'package:pointycastle/export.dart';

/// 테스트용 RSA 키 쌍.
class TestKeyPair {
  final String keyId;
  final RSAPublicKey publicKey;
  final RSAPrivateKey privateKey;

  const TestKeyPair({required this.keyId, required this.publicKey, required this.privateKey});

  factory TestKeyPair.generate(String keyId) {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    secureRandom.seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)))));
    final generator = RSAKeyGenerator()
      ..init(ParametersWithRandom(RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64), secureRandom));
    final pair = generator.generateKeyPair();
    return TestKeyPair(keyId: keyId, publicKey: pair.publicKey, privateKey: pair.privateKey);
  }

  /// RS256으로 서명한 JWT.
  String sign(Map<String, Object?> payload, {String? keyId}) {
    final header = {'alg': 'RS256', 'typ': 'JWT', 'kid': keyId ?? this.keyId};
    final signingInput = '${_encodeJson(header)}.${_encodeJson(payload)}';
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(Uint8List.fromList(utf8.encode(signingInput)));
    return '$signingInput.${encodeBase64Url(signature.bytes)}';
  }

  /// JWK Set에 넣을 공개 키.
  Map<String, Object?> toJwk() => {
    'kty': 'RSA',
    'alg': 'RS256',
    'use': 'sig',
    'kid': keyId,
    'n': encodeBase64Url(_encodeBigInt(publicKey.modulus!)),
    'e': encodeBase64Url(_encodeBigInt(publicKey.publicExponent!)),
  };
}

/// Auth 에뮬레이터처럼 서명 없이 만든 JWT.
String createUnsignedToken(Map<String, Object?> payload) {
  return '${_encodeJson({'alg': 'none', 'typ': 'JWT'})}.${_encodeJson(payload)}.';
}

/// 키 목록을 그대로 돌려주는 [PublicKeySource].
class FixedKeySource implements PublicKeySource {
  final Map<String, RSAPublicKey> keys;

  FixedKeySource(this.keys);

  @override
  Future<RSAPublicKey?> getKey(String keyId) async => keys[keyId];
}

/// 초 단위 epoch.
int toSeconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

/// 패딩 없는 base64url.
String encodeBase64Url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String _encodeJson(Map<String, Object?> value) => encodeBase64Url(utf8.encode(jsonEncode(value)));

Uint8List _encodeBigInt(BigInt value) {
  final hex = value.toRadixString(16);
  final padded = hex.length.isOdd ? '0$hex' : hex;
  return Uint8List.fromList([
    for (var i = 0; i < padded.length; i += 2) int.parse(padded.substring(i, i + 2), radix: 16),
  ]);
}
