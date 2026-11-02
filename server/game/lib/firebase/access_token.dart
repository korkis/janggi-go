import 'dart:convert';

import 'package:http/http.dart' as http;

import '../clock.dart';

/// Firestore, RTDB, Cloud Tasks REST API에 넣을 OAuth 액세스 토큰.
abstract interface class AccessTokenProvider {
  Future<String> getAccessToken();
}

/// 에뮬레이터용. Firestore·RTDB 에뮬레이터는 `Bearer owner`를 관리자 권한으로 보고 보안 규칙을 건너뛴다.
class EmulatorAccessTokenProvider implements AccessTokenProvider {
  const EmulatorAccessTokenProvider();

  @override
  Future<String> getAccessToken() async => 'owner';
}

/// 운영용. Cloud Run 메타데이터 서버에서 서비스 계정 토큰을 받아 만료 직전까지 캐시한다.
class MetadataServerAccessTokenProvider implements AccessTokenProvider {
  final http.Client httpClient;
  final Clock clock;

  String? _token;
  DateTime? _refreshAt;

  MetadataServerAccessTokenProvider({required this.httpClient, this.clock = utcNow});

  @override
  Future<String> getAccessToken() async {
    final token = _token;
    final refreshAt = _refreshAt;
    final now = clock();
    if (token != null && refreshAt != null && now.isBefore(refreshAt)) {
      return token;
    }
    final response = await httpClient.get(_tokenUrl, headers: {'Metadata-Flavor': 'Google'});
    if (response.statusCode != 200) {
      throw http.ClientException('액세스 토큰을 받지 못했습니다: ${response.statusCode}', _tokenUrl);
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final newToken = body['access_token'] as String;
    final expiresIn = body['expires_in'] as int;
    _token = newToken;
    // 요청 도중 만료되지 않게 1분 일찍 새로 받는다.
    _refreshAt = now.add(Duration(seconds: expiresIn) - const Duration(minutes: 1));
    return newToken;
  }

  // RTDB REST API는 firebase.database와 userinfo.email 범위를 요구한다. Firestore와 Cloud Tasks는 cloud-platform을 쓴다.
  static final _tokenUrl =
      Uri.parse('http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token').replace(
        queryParameters: {
          'scopes': [
            'https://www.googleapis.com/auth/cloud-platform',
            'https://www.googleapis.com/auth/firebase.database',
            'https://www.googleapis.com/auth/userinfo.email',
          ].join(','),
        },
      );
}

/// 모든 요청에 `Authorization: Bearer <액세스 토큰>`을 붙이는 HTTP 클라이언트.
class AuthorizedClient extends http.BaseClient {
  final http.Client inner;
  final AccessTokenProvider tokenProvider;

  AuthorizedClient({required this.inner, required this.tokenProvider});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['Authorization'] = 'Bearer ${await tokenProvider.getAccessToken()}';
    return inner.send(request);
  }
}
