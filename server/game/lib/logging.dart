import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 로그 심각도. Cloud Logging의 `severity` 값과 이름이 같다.
enum LogSeverity {
  debug,
  info,
  warning,
  error;

  String get cloudName => name.toUpperCase();
}

/// 로그 한 줄을 어디에 어떤 모양으로 쓰는지.
enum LogFormat {
  /// Cloud Run이 읽는 JSON 한 줄. `severity`, `message`와 추가 필드를 담는다.
  json,

  /// 개발 PC 터미널에서 읽기 쉬운 한 줄.
  text,
}

/// 요청 하나의 Cloud Trace 이름을 담는 Zone 키. 같은 요청의 로그를 Cloud Logging에서 묶어 본다.
final _traceZoneKey = Object();

/// 대국 서버 전체가 쓰는 로거. 메시지의 코드 식별자는 영어, 나머지는 한글로 쓴다(`docs/dev_rules.md`).
///
/// 큰 payload 전체를 넣지 않고 식별자와 상태 필드 위주로 [fields]에 담는다.
class GameLogger {
  final LogFormat format;
  final LogSeverity minSeverity;

  /// 한 줄씩 받는 곳. 테스트에서 바꾼다.
  final void Function(String line) _write;

  GameLogger({required this.format, required this.minSeverity, void Function(String line)? write})
    : _write = write ?? stdout.writeln;

  void debug(String message, [Map<String, Object?>? fields]) => log(LogSeverity.debug, message, fields: fields);

  void info(String message, [Map<String, Object?>? fields]) => log(LogSeverity.info, message, fields: fields);

  void warning(String message, [Map<String, Object?>? fields]) => log(LogSeverity.warning, message, fields: fields);

  void error(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      log(LogSeverity.error, message, fields: fields, error: error, stackTrace: stackTrace);

  void log(
    LogSeverity severity,
    String message, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (severity.index < minSeverity.index) {
      return;
    }
    switch (format) {
      case LogFormat.json:
        _write(_formatJson(severity, message, fields, error, stackTrace));
      case LogFormat.text:
        _write(_formatText(severity, message, fields, error, stackTrace));
    }
  }

  String _formatJson(
    LogSeverity severity,
    String message,
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final entry = <String, Object?>{'severity': severity.cloudName, ...?fields};
    // Error Reporting은 message에 스택이 있으면 오류로 묶는다.
    if (error != null) {
      entry['message'] = '$message\n$error${stackTrace == null ? '' : '\n$stackTrace'}';
    } else {
      entry['message'] = message;
    }
    final trace = Zone.current[_traceZoneKey];
    if (trace != null) {
      entry['logging.googleapis.com/trace'] = trace;
    }
    return jsonEncode(entry, toEncodable: _toEncodable);
  }

  String _formatText(
    LogSeverity severity,
    String message,
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final buffer = StringBuffer()
      ..write(DateTime.now().toUtc().toIso8601String())
      ..write(' ')
      ..write(severity.cloudName.padRight(8))
      ..write(message);
    if (fields != null && fields.isNotEmpty) {
      buffer
        ..write(' ')
        ..write(jsonEncode(fields, toEncodable: _toEncodable));
    }
    if (error != null) {
      buffer
        ..write('\n')
        ..write(error);
    }
    if (stackTrace != null) {
      buffer
        ..write('\n')
        ..write(stackTrace);
    }
    return buffer.toString();
  }

  static Object? _toEncodable(Object? value) {
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }
}

/// [body]를 Cloud Trace [traceName](`projects/{p}/traces/{id}`)에 묶어 실행한다. 그 안의 로그에 trace가 붙는다.
R runWithTrace<R>(String? traceName, R Function() body) {
  if (traceName == null) {
    return body();
  }
  return runZoned(body, zoneValues: {_traceZoneKey: traceName});
}

/// Cloud Run이 넣어 주는 `X-Cloud-Trace-Context`(`TRACE_ID/SPAN_ID;o=1`)로 trace 이름을 만든다. 없으면 null.
String? getTraceName(String projectId, String? traceContextHeader) {
  if (traceContextHeader == null) {
    return null;
  }
  final traceId = traceContextHeader.split('/').first;
  if (traceId.isEmpty) {
    return null;
  }
  return 'projects/$projectId/traces/$traceId';
}
