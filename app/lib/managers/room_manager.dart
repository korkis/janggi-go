import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/room.dart';
import '../repositories/app_repositories.dart';

/// 방 대기실 화면 하나의 방 상태. 화면이 만들고 `dispose()`한다.
///
/// `rooms/{roomId}`를 듣는다. 방은 대국 서버만 쓰므로 상대가 들어오고 나가는 것, 대국 시작, 방 닫힘이 모두 여기로 온다.
class RoomManager extends ChangeNotifier {
  final String roomId;

  StreamSubscription<Room?>? _subscription;
  Room? _room;
  var _loaded = false;
  var _failed = false;

  RoomManager({required this.roomId}) {
    _subscription = repositories.roomRepository.watchRoom(roomId).listen(_onRoomChanged, onError: _onRoomError);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// 방. 아직 받지 못했거나 방이 없으면 null.
  Room? get room => _room;

  /// 방을 한 번이라도 받았다(없다는 것 포함).
  bool get loaded => _loaded;

  /// 방을 듣지 못했다.
  bool get failed => _failed;

  void _onRoomChanged(Room? room) {
    _room = room;
    _loaded = true;
    _failed = false;
    notifyListeners();
  }

  void _onRoomError(Object error, StackTrace stackTrace) {
    developer.log('RoomManager 방 듣기 실패', error: error, stackTrace: stackTrace);
    _failed = true;
    notifyListeners();
  }
}
