import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:janggi_core/janggi_core.dart';

import '../models/game_enums.dart';
import '../models/room.dart';
import 'game_server_call.dart';

/// Firestore `rooms` 컬렉션과 대국 서버의 방 API. 방은 대국 서버만 쓰고 앱은 읽기만 한다.
class RoomRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  /// 대국 서버 주소를 돌려준다. 운영 주소가 없는 빌드에서도 앱이 켜지도록 부를 때 구한다.
  final Uri Function() getServerUrl;

  RoomRepository({required this.firestore, required this.functions, required this.getServerUrl});

  /// 방 목록에서 한 번에 읽는 방 수.
  static const roomListLimit = 50;

  CollectionReference<Map<String, dynamic>> get _rooms => firestore.collection('rooms');

  /// 방을 듣는다. 방이 없으면 null을 보낸다.
  Stream<Room?> watchRoom(String roomId) => _rooms.doc(roomId).snapshots().map(_decode);

  /// 방. 없으면 null.
  Future<Room?> getRoom(String roomId) async => _decode(await _rooms.doc(roomId).get());

  /// 방 목록. 공개되어 상대를 기다리는 방을 최근에 만든 순서로 [roomListLimit]개까지 읽는다. 보안 규칙이 이 조건만 허용한다.
  Future<List<({String id, Room room})>> getRooms() async {
    final snapshot = await _rooms
        .where('listed', isEqualTo: true)
        .where('status', isEqualTo: RoomStatus.waiting.name)
        .orderBy('createdAt', descending: true)
        .limit(roomListLimit)
        .get();
    return [for (final document in snapshot.docs) (id: document.id, room: Room.fromJson(document.data()))];
  }

  /// 방을 만들고 방 ID를 돌려준다. 접장기가 아니면 [handicapPieces]는 null이다. [rankRange]는 공개 방에서만 준다.
  Future<String> createRoom({
    required SideChoice hostSide,
    required HandicapRemover? handicapRemover,
    required List<HandicapPiece>? handicapPieces,
    required bool listed,
    required RankRange? rankRange,
  }) async {
    final result = await _call('createRoom', {
      'hostSide': hostSide.name,
      'listed': listed,
      if (handicapRemover != null && handicapPieces != null)
        'handicap': {
          'remover': handicapRemover.name,
          'pieces': [for (final piece in handicapPieces) piece.name],
        },
      if (rankRange != null) 'rankRange': {'min': rankRange.min, 'max': rankRange.max},
    });
    return result['roomId'] as String;
  }

  /// 방의 빈자리에 앉는다. 이미 이 방에 있으면 그대로 성공한다.
  Future<void> joinRoom(String roomId) async {
    await _call('joinRoom', {'roomId': roomId});
  }

  /// 방에서 나간다. 방장이면 방이 닫힌다.
  Future<void> leaveRoom(String roomId) async {
    await _call('leaveRoom', {'roomId': roomId});
  }

  /// 방장이 상대를 내보낸다.
  Future<void> kickGuest(String roomId) async {
    await _call('kickGuest', {'roomId': roomId});
  }

  /// 방장이 대국을 시작한다. 두 사람의 `player_states.gameId`가 생기므로 화면은 그 값을 보고 상차림으로 간다.
  Future<void> startRoomGame(String roomId) async {
    await _call('startRoomGame', {'roomId': roomId});
  }

  Future<Map<String, Object?>> _call(String name, Map<String, Object?>? data) =>
      callGameServer(functions, getServerUrl(), name, data);

  static Room? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return data == null ? null : Room.fromJson(data);
  }
}
