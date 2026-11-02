import 'package:cloud_functions/cloud_functions.dart';

import '../models/game_error_code.dart';
import '../utils/app_exception.dart';

/// 대국 서버([serverUrl])의 API [name]을 Callable 프로토콜로 부르고 결과 객체를 돌려준다(`docs/server.md`의 호출 방식).
/// 결과가 없으면 빈 Map이다. 서버가 알려 준 거절 사유는 [AppException]으로 바꾼다.
///
/// 대국 서버 API는 주요 변경 대상 컬렉션의 repository(`GameRepository`, `RoomRepository`)가 이것으로 부른다.
Future<Map<String, Object?>> callGameServer(
  FirebaseFunctions functions,
  Uri serverUrl,
  String name,
  Map<String, Object?>? data,
) async {
  final callable = functions.httpsCallableFromUrl(serverUrl.resolve(name).toString());
  try {
    final result = await callable.call<Object?>(data);
    final value = result.data;
    return value is Map ? {for (final entry in value.entries) entry.key.toString(): entry.value} : const {};
  } on FirebaseFunctionsException catch (error) {
    final details = error.details;
    final code = details is Map ? GameErrorCode.fromName(details['code']) : null;
    final exception = code == null ? null : AppException.fromGameErrorCode(code);
    if (exception == null) {
      rethrow;
    }
    throw exception;
  }
}
