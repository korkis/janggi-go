// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Room _$RoomFromJson(Map<String, dynamic> json) => $checkedCreate('Room', json, ($checkedConvert) {
  final val = Room(
    hostUid: $checkedConvert('hostUid', (v) => v as String),
    host: $checkedConvert('host', (v) => RoomPlayer.fromJson(v as Map<String, dynamic>)),
    guestUid: $checkedConvert('guestUid', (v) => v as String?),
    guest: $checkedConvert('guest', (v) => v == null ? null : RoomPlayer.fromJson(v as Map<String, dynamic>)),
    status: $checkedConvert('status', (v) => $enumDecode(_$RoomStatusEnumMap, v)),
    listed: $checkedConvert('listed', (v) => v as bool),
    hostSide: $checkedConvert('hostSide', (v) => $enumDecode(_$SideChoiceEnumMap, v)),
    handicap: $checkedConvert('handicap', (v) => v == null ? null : RoomHandicap.fromJson(v as Map<String, dynamic>)),
    rankRange: $checkedConvert('rankRange', (v) => v == null ? null : RankRange.fromJson(v as Map<String, dynamic>)),
    gameId: $checkedConvert('gameId', (v) => v as String?),
    kickedUids: $checkedConvert('kickedUids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
    hostAbsentSince: $checkedConvert(
      'hostAbsentSince',
      (v) => _$JsonConverterFromJson<DateTime, DateTime>(v, const TimestampConverter().fromJson),
    ),
    guestAbsentSince: $checkedConvert(
      'guestAbsentSince',
      (v) => _$JsonConverterFromJson<DateTime, DateTime>(v, const TimestampConverter().fromJson),
    ),
    createdAt: $checkedConvert('createdAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
    updatedAt: $checkedConvert('updatedAt', (v) => const TimestampConverter().fromJson(v as DateTime)),
  );
  return val;
});

Map<String, dynamic> _$RoomToJson(Room instance) => <String, dynamic>{
  'hostUid': instance.hostUid,
  'host': instance.host.toJson(),
  'guestUid': instance.guestUid,
  'guest': instance.guest?.toJson(),
  'status': _$RoomStatusEnumMap[instance.status]!,
  'listed': instance.listed,
  'hostSide': _$SideChoiceEnumMap[instance.hostSide]!,
  'handicap': instance.handicap?.toJson(),
  'rankRange': instance.rankRange?.toJson(),
  'gameId': instance.gameId,
  'kickedUids': instance.kickedUids,
  'hostAbsentSince': _$JsonConverterToJson<DateTime, DateTime>(
    instance.hostAbsentSince,
    const TimestampConverter().toJson,
  ),
  'guestAbsentSince': _$JsonConverterToJson<DateTime, DateTime>(
    instance.guestAbsentSince,
    const TimestampConverter().toJson,
  ),
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
};

const _$RoomStatusEnumMap = {RoomStatus.waiting: 'waiting', RoomStatus.playing: 'playing', RoomStatus.closed: 'closed'};

const _$SideChoiceEnumMap = {SideChoice.cho: 'cho', SideChoice.han: 'han', SideChoice.random: 'random'};

Value? _$JsonConverterFromJson<Json, Value>(Object? json, Value? Function(Json json) fromJson) =>
    json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(Value? value, Json? Function(Value value) toJson) =>
    value == null ? null : toJson(value);

RoomPlayer _$RoomPlayerFromJson(Map<String, dynamic> json) => $checkedCreate('RoomPlayer', json, ($checkedConvert) {
  final val = RoomPlayer(
    nickname: $checkedConvert('nickname', (v) => v as String),
    rankLevel: $checkedConvert('rankLevel', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$RoomPlayerToJson(RoomPlayer instance) => <String, dynamic>{
  'nickname': instance.nickname,
  'rankLevel': instance.rankLevel,
};

RoomHandicap _$RoomHandicapFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RoomHandicap', json, ($checkedConvert) {
      final val = RoomHandicap(
        remover: $checkedConvert('remover', (v) => $enumDecode(_$HandicapRemoverEnumMap, v)),
        pieces: $checkedConvert(
          'pieces',
          (v) => (v as List<dynamic>).map((e) => $enumDecode(_$HandicapPieceEnumMap, e)).toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$RoomHandicapToJson(RoomHandicap instance) => <String, dynamic>{
  'remover': _$HandicapRemoverEnumMap[instance.remover]!,
  'pieces': instance.pieces.map((e) => _$HandicapPieceEnumMap[e]!).toList(),
};

const _$HandicapRemoverEnumMap = {HandicapRemover.creator: 'creator', HandicapRemover.opponent: 'opponent'};

const _$HandicapPieceEnumMap = {
  HandicapPiece.leftChariot: 'leftChariot',
  HandicapPiece.rightChariot: 'rightChariot',
  HandicapPiece.leftCannon: 'leftCannon',
  HandicapPiece.rightCannon: 'rightCannon',
  HandicapPiece.leftHorse: 'leftHorse',
  HandicapPiece.rightHorse: 'rightHorse',
  HandicapPiece.leftElephant: 'leftElephant',
  HandicapPiece.rightElephant: 'rightElephant',
};

RankRange _$RankRangeFromJson(Map<String, dynamic> json) => $checkedCreate('RankRange', json, ($checkedConvert) {
  final val = RankRange(
    min: $checkedConvert('min', (v) => (v as num).toInt()),
    max: $checkedConvert('max', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$RankRangeToJson(RankRange instance) => <String, dynamic>{
  'min': instance.min,
  'max': instance.max,
};
