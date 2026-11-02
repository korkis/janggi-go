import 'package:json_annotation/json_annotation.dart';

/// Firestore timestamp 필드. `FirestoreCodec`이 이미 UTC `DateTime`으로 읽으므로 그대로 넘긴다.
class TimestampConverter implements JsonConverter<DateTime, DateTime> {
  const TimestampConverter();

  @override
  DateTime fromJson(DateTime json) => json.toUtc();

  @override
  DateTime toJson(DateTime object) => object.toUtc();
}
