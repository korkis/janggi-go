/// Firestore REST API의 `Value` JSON과 Dart 값 사이의 변환.
///
/// Dart 쪽 값은 `null`, `bool`, `int`, `double`, `String`, UTC `DateTime`(timestamp), `List`, `Map<String, Object?>`이다.
/// 참조(`referenceValue`)는 문서 이름 문자열로 읽는다. 바이트와 GeoPoint는 쓰지 않으므로 받으면 오류로 본다.
abstract final class FirestoreCodec {
  /// 문서의 `fields`를 Dart 맵으로 읽는다.
  static Map<String, Object?> decodeFields(Map<String, Object?>? fields) {
    if (fields == null) {
      return {};
    }
    return {for (final entry in fields.entries) entry.key: decodeValue(entry.value as Map<String, Object?>)};
  }

  /// Dart 맵을 문서의 `fields`로 쓴다.
  static Map<String, Object?> encodeFields(Map<String, Object?> data) {
    return {for (final entry in data.entries) entry.key: encodeValue(entry.value)};
  }

  static Object? decodeValue(Map<String, Object?> value) {
    if (value.length != 1) {
      throw FormatException('Firestore Value에는 값이 하나만 있어야 합니다: ${value.keys}');
    }
    final MapEntry(:key, value: raw) = value.entries.single;
    switch (key) {
      case 'nullValue':
        return null;
      case 'booleanValue':
        return raw as bool;
      case 'integerValue':
        // int64는 JSON에서 문자열로 온다.
        return int.parse(raw as String);
      case 'doubleValue':
        return _decodeDouble(raw);
      case 'stringValue':
      case 'referenceValue':
        return raw as String;
      case 'timestampValue':
        return DateTime.parse(raw as String).toUtc();
      case 'arrayValue':
        final values = (raw as Map<String, Object?>)['values'] as List<Object?>? ?? const [];
        return [for (final item in values) decodeValue(item as Map<String, Object?>)];
      case 'mapValue':
        return decodeFields((raw as Map<String, Object?>)['fields'] as Map<String, Object?>?);
    }
    throw FormatException('지원하지 않는 Firestore Value입니다: $key');
  }

  static Map<String, Object?> encodeValue(Object? value) {
    switch (value) {
      case null:
        return {'nullValue': null};
      case bool():
        return {'booleanValue': value};
      case int():
        return {'integerValue': value.toString()};
      case double():
        return {'doubleValue': _encodeDouble(value)};
      case String():
        return {'stringValue': value};
      case DateTime():
        if (!value.isUtc) {
          throw ArgumentError.value(value, 'value', '시간은 UTC로 저장합니다');
        }
        return {'timestampValue': value.toIso8601String()};
      case List<Object?>():
        return {
          'arrayValue': {'values': value.map(encodeValue).toList()},
        };
      case Map<String, Object?>():
        return {
          'mapValue': {'fields': encodeFields(value)},
        };
    }
    throw ArgumentError.value(value, 'value', 'Firestore에 쓸 수 없는 타입입니다');
  }

  static double _decodeDouble(Object? raw) {
    // NaN과 무한대는 JSON 숫자가 아니라 문자열로 온다.
    if (raw is String) {
      return double.parse(raw);
    }
    return (raw as num).toDouble();
  }

  static Object _encodeDouble(double value) {
    if (value.isNaN || value.isInfinite) {
      return value.toString();
    }
    return value;
  }
}
