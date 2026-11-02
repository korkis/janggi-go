// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Rating _$RatingFromJson(Map<String, dynamic> json) => $checkedCreate('Rating', json, ($checkedConvert) {
  final val = Rating(
    rating: $checkedConvert('rating', (v) => (v as num).toDouble()),
    ratedGames: $checkedConvert('ratedGames', (v) => (v as num).toInt()),
    updatedAt: $checkedConvert('updatedAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
  );
  return val;
});

Map<String, dynamic> _$RatingToJson(Rating instance) => <String, dynamic>{
  'rating': instance.rating,
  'ratedGames': instance.ratedGames,
  'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
};
