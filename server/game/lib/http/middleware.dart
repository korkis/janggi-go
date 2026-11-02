import 'dart:async';

import 'package:shelf/shelf.dart';

import '../logging.dart';

/// 웹 앱이 다른 출처에서 부를 수 있게 CORS 헤더를 붙이고 preflight(`OPTIONS`)에 답한다.
///
/// 인증은 쿠키가 아니라 `Authorization` 헤더의 ID token이므로 모든 출처를 허용해도 된다. Functions의 `cors: true`와 같다.
Middleware corsMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      final origin = request.headers['origin'];
      final headers = <String, String>{'Access-Control-Allow-Origin': origin ?? '*', 'Vary': 'Origin'};
      if (request.method == 'OPTIONS') {
        return Response(
          204,
          headers: {
            ...headers,
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers':
                request.headers['access-control-request-headers'] ?? 'Authorization, Content-Type',
            'Access-Control-Max-Age': '3600',
          },
        );
      }
      final response = await inner(request);
      return response.change(headers: headers);
    };
  };
}

/// 요청 안의 로그에 Cloud Trace를 붙인다.
Middleware traceMiddleware(String projectId) {
  return (Handler inner) {
    return (Request request) {
      final traceName = getTraceName(projectId, request.headers['x-cloud-trace-context']);
      return runWithTrace<FutureOr<Response>>(traceName, () => inner(request));
    };
  };
}
