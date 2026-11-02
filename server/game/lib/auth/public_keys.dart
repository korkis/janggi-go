import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

import '../clock.dart';
import 'jwt.dart';

/// 토큰 서명을 검사할 공개 키를 `kid`로 찾는다.
abstract interface class PublicKeySource {
  /// [keyId]의 키. 없으면 null.
  Future<RSAPublicKey?> getKey(String keyId);
}

/// Google이 JWK로 공개하는 키 목록을 받아 `Cache-Control: max-age` 동안 캐시한다.
///
/// Firebase ID token은 [firebaseIdTokenKeysUrl], Cloud Tasks의 OIDC 토큰은 [googleOidcKeysUrl]의 키로 서명된다.
class GoogleJwkKeySource implements PublicKeySource {
  final Uri url;
  final http.Client httpClient;
  final Clock clock;

  Map<String, RSAPublicKey> _keys = const {};

  // 이 시각까지 캐시한 키를 쓴다.
  DateTime? _expiresAt;

  // 마지막으로 받은 시각. 모르는 kid가 들어올 때마다 다시 받지 않도록 간격을 둔다.
  DateTime? _fetchedAt;

  GoogleJwkKeySource({required this.url, required this.httpClient, this.clock = utcNow});

  @override
  Future<RSAPublicKey?> getKey(String keyId) async {
    final now = clock();
    final expiresAt = _expiresAt;
    if (expiresAt == null || !now.isBefore(expiresAt)) {
      await _fetch(now);
      return _keys[keyId];
    }
    final key = _keys[keyId];
    if (key != null) {
      return key;
    }
    // 키가 바뀐 직후에는 캐시에 새 kid가 없을 수 있다.
    final fetchedAt = _fetchedAt;
    if (fetchedAt != null && now.difference(fetchedAt) >= _minRefetchInterval) {
      await _fetch(now);
    }
    return _keys[keyId];
  }

  Future<void> _fetch(DateTime now) async {
    final response = await httpClient.get(url);
    if (response.statusCode != 200) {
      throw http.ClientException('공개 키를 받지 못했습니다: ${response.statusCode}', url);
    }
    _keys = parseJwks(jsonDecode(response.body));
    _fetchedAt = now;
    _expiresAt = now.add(_getMaxAge(response.headers['cache-control']));
  }

  static Duration _getMaxAge(String? cacheControl) {
    final match = RegExp(r'max-age=(\d+)').firstMatch(cacheControl ?? '');
    if (match == null) {
      return _minRefetchInterval;
    }
    return Duration(seconds: int.parse(match.group(1)!));
  }

  static const _minRefetchInterval = Duration(minutes: 1);

  static final firebaseIdTokenKeysUrl = Uri.parse(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
  );

  static final googleOidcKeysUrl = Uri.parse('https://www.googleapis.com/oauth2/v3/certs');
}

/// JWK Set(`{"keys": [...]}`)의 RSA 키를 kid별로 읽는다. RSA가 아닌 키는 건너뛴다.
Map<String, RSAPublicKey> parseJwks(Object? json) {
  if (json is! Map<String, Object?> || json['keys'] is! List<Object?>) {
    throw const FormatException('JWK Set 모양이 아닙니다');
  }
  final keys = <String, RSAPublicKey>{};
  for (final entry in json['keys'] as List<Object?>) {
    if (entry is! Map<String, Object?> || entry['kty'] != 'RSA') {
      continue;
    }
    final kid = entry['kid'];
    final n = entry['n'];
    final e = entry['e'];
    if (kid is! String || n is! String || e is! String) {
      throw const FormatException('JWK에 kid, n, e가 없습니다');
    }
    keys[kid] = RSAPublicKey(decodeUnsignedBigInt(decodeBase64Url(n)), decodeUnsignedBigInt(decodeBase64Url(e)));
  }
  return keys;
}
