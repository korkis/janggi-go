import 'dart:math';

import '../firebase/firestore_client.dart';
import '../models/game_enums.dart';
import '../models/room.dart';

/// Firestore `rooms/{roomId}`. 방이다. 대국 서버만 쓴다.
class RoomsRepository {
  final FirestoreClient firestore;
  final Random _random;

  RoomsRepository({required this.firestore, Random? random}) : _random = random ?? Random.secure();

  static const collection = 'rooms';

  static const _idCharacters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static const _idLength = 20;

  /// 추측할 수 없는 20자 방 ID. 초대 링크에 들어가므로 비공개 방은 이 ID를 아는 사람만 들어온다.
  String createRoomId() => List.generate(_idLength, (_) => _idCharacters[_random.nextInt(_idCharacters.length)]).join();

  /// 방. 없으면 null.
  Future<Room?> getRoom(String roomId) async {
    final data = await firestore.getDocument('$collection/$roomId');
    return data == null ? null : Room.fromJson(data);
  }

  Future<Room?> getRoomInTransaction(FirestoreTransaction transaction, String roomId) async {
    final data = await transaction.get('$collection/$roomId');
    return data == null ? null : Room.fromJson(data);
  }

  /// 새 방을 만든다. 같은 ID가 있으면 커밋이 실패한다.
  void createRoomInTransaction(FirestoreTransaction transaction, String roomId, Room room) {
    transaction.create('$collection/$roomId', room.toJson());
  }

  /// 상대 자리를 바꾼다. [guestUid]가 null이면 빈자리다. 상대의 연결 확인 기록은 지운다.
  /// [kickedUids]를 주면 내보낸 사람 목록도 바꾼다.
  void updateGuestInTransaction(
    FirestoreTransaction transaction,
    String roomId, {
    required String? guestUid,
    required RoomPlayer? guest,
    List<String>? kickedUids,
    required DateTime now,
  }) {
    transaction.update('$collection/$roomId', {
      'guestUid': guestUid,
      'guest': guest?.toJson(),
      'guestAbsentSince': null,
      'kickedUids': ?kickedUids,
      'updatedAt': now,
    });
  }

  /// 방 상태를 바꾼다. [gameId]를 주면 방의 대국도 바꾼다.
  void updateStatusInTransaction(
    FirestoreTransaction transaction,
    String roomId, {
    required RoomStatus status,
    String? gameId,
    required DateTime now,
  }) {
    transaction.update('$collection/$roomId', {'status': status.name, 'gameId': ?gameId, 'updatedAt': now});
  }

  /// `checkRoom`이 본 방장과 상대의 연결 없음 시각을 쓴다.
  void updateAbsenceInTransaction(
    FirestoreTransaction transaction,
    String roomId, {
    required DateTime? hostAbsentSince,
    required DateTime? guestAbsentSince,
    required DateTime now,
  }) {
    transaction.update('$collection/$roomId', {
      'hostAbsentSince': hostAbsentSince,
      'guestAbsentSince': guestAbsentSince,
      'updatedAt': now,
    });
  }
}
