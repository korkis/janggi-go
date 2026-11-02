import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'quick_queue_entry.g.dart';

/// Firestore `quick_queue/{uid}`. 빠른 대국 대기열의 한 사람이다. 서버 전용이라 대국 서버에만 선언한다.
@JsonSerializable(createToJson: true)
class QuickQueueEntry {
  /// 들어올 때의 레이팅.
  final double rating;

  /// 기다리기 시작한 시각. 매칭 범위 넓히기에 쓴다.
  @TimestampConverter()
  final DateTime joinedAt;

  const QuickQueueEntry({required this.rating, required this.joinedAt});

  factory QuickQueueEntry.fromJson(Map<String, dynamic> json) => _$QuickQueueEntryFromJson(json);

  Map<String, dynamic> toJson() => _$QuickQueueEntryToJson(this);
}
