import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// Firestore Timestamp와 UTC DateTime 사이의 변환.
class TimestampConverter implements JsonConverter<DateTime, Timestamp> {
  const TimestampConverter();

  @override
  DateTime fromJson(Timestamp json) => json.toDate().toUtc();

  @override
  Timestamp toJson(DateTime object) => Timestamp.fromDate(object);
}
