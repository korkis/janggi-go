import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'rating.g.dart';

/// Firestore `ratings/{uid}`. 사용자에게 보이지 않는 레이팅이다(`docs/game/rank.md`). 서버 전용이라 대국 서버에만 선언한다.
///
/// 첫 급수 대국을 끝낼 때 만든다. 문서가 없으면 처음 레이팅(`initialRating`)으로 본다.
@JsonSerializable(createToJson: true)
class Rating {
  final double rating;

  /// 급수에 반영된 대국 수. K 값을 고르는 데 쓴다.
  final int ratedGames;

  @TimestampConverter()
  final DateTime updatedAt;

  const Rating({required this.rating, required this.ratedGames, required this.updatedAt});

  factory Rating.fromJson(Map<String, dynamic> json) => _$RatingFromJson(json);

  Map<String, dynamic> toJson() => _$RatingToJson(this);
}
