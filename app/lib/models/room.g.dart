// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Room _$RoomFromJson(Map<String, dynamic> json) => Room(
  hostUid: json['hostUid'] as String,
  host: RoomPlayer.fromJson(json['host'] as Map<String, dynamic>),
  guestUid: json['guestUid'] as String?,
  guest: json['guest'] == null ? null : RoomPlayer.fromJson(json['guest'] as Map<String, dynamic>),
  status: $enumDecode(_$RoomStatusEnumMap, json['status']),
  listed: json['listed'] as bool,
  hostSide: $enumDecode(_$SideChoiceEnumMap, json['hostSide']),
  handicap: json['handicap'] == null ? null : RoomHandicap.fromJson(json['handicap'] as Map<String, dynamic>),
  rankRange: json['rankRange'] == null ? null : RankRange.fromJson(json['rankRange'] as Map<String, dynamic>),
  gameId: json['gameId'] as String?,
  kickedUids: (json['kickedUids'] as List<dynamic>).map((e) => e as String).toList(),
  hostAbsentSince: _$JsonConverterFromJson<Timestamp, DateTime>(
    json['hostAbsentSince'],
    const TimestampConverter().fromJson,
  ),
  guestAbsentSince: _$JsonConverterFromJson<Timestamp, DateTime>(
    json['guestAbsentSince'],
    const TimestampConverter().fromJson,
  ),
  createdAt: const TimestampConverter().fromJson(json['createdAt'] as Timestamp),
  updatedAt: const TimestampConverter().fromJson(json['updatedAt'] as Timestamp),
);

const _$RoomStatusEnumMap = {RoomStatus.waiting: 'waiting', RoomStatus.playing: 'playing', RoomStatus.closed: 'closed'};

const _$SideChoiceEnumMap = {SideChoice.cho: 'cho', SideChoice.han: 'han', SideChoice.random: 'random'};

Value? _$JsonConverterFromJson<Json, Value>(Object? json, Value? Function(Json json) fromJson) =>
    json == null ? null : fromJson(json as Json);

RoomPlayer _$RoomPlayerFromJson(Map<String, dynamic> json) =>
    RoomPlayer(nickname: json['nickname'] as String, rankLevel: (json['rankLevel'] as num).toInt());

RoomHandicap _$RoomHandicapFromJson(Map<String, dynamic> json) => RoomHandicap(
  remover: $enumDecode(_$HandicapRemoverEnumMap, json['remover']),
  pieces: (json['pieces'] as List<dynamic>).map((e) => $enumDecode(_$HandicapPieceEnumMap, e)).toList(),
);

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

RankRange _$RankRangeFromJson(Map<String, dynamic> json) =>
    RankRange(min: (json['min'] as num).toInt(), max: (json['max'] as num).toInt());
