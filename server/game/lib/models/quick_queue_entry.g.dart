// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_queue_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuickQueueEntry _$QuickQueueEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('QuickQueueEntry', json, ($checkedConvert) {
      final val = QuickQueueEntry(
        rating: $checkedConvert('rating', (v) => (v as num).toDouble()),
        joinedAt: $checkedConvert('joinedAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
      );
      return val;
    });

Map<String, dynamic> _$QuickQueueEntryToJson(QuickQueueEntry instance) => <String, dynamic>{
  'rating': instance.rating,
  'joinedAt': const TimestampConverter().toJson(instance.joinedAt),
};
