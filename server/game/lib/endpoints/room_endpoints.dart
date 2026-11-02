import '../http/callable.dart';
import '../services/room_service.dart';
import 'param_checks.dart';

// 방 하나에 대한 API들이다(`docs/server.md`의 방). 파라미터가 `roomId` 하나로 같아 한 파일에 둔다.

/// 방 API의 파라미터.
class RoomParams {
  final String roomId;

  const RoomParams({required this.roomId});
}

/// 파라미터: `roomId`.
RoomParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  return RoomParams(roomId: requireRoomId(params, 'roomId'));
}

/// 방의 빈자리에 앉는다. 초대 링크와 방 목록이 모두 이것을 쓴다. 결과는 없다.
class JoinRoomEndpoint extends CallableEndpoint {
  final RoomService roomService;

  JoinRoomEndpoint({required this.roomService});

  @override
  String get name => 'joinRoom';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    await roomService.joinRoom(params.roomId, uid: request.uid, user: request.user, now: request.receivedAt);
    return null;
  }
}

/// 방에서 나간다. 방장이면 방을 닫는다. 결과는 없다.
class LeaveRoomEndpoint extends CallableEndpoint {
  final RoomService roomService;

  LeaveRoomEndpoint({required this.roomService});

  @override
  String get name => 'leaveRoom';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    await roomService.leaveRoom(params.roomId, uid: request.uid, now: request.receivedAt);
    return null;
  }
}

/// 방장이 상대를 내보낸다. 내보낸 사람은 방이 닫힐 때까지 못 들어온다. 결과는 없다.
class KickGuestEndpoint extends CallableEndpoint {
  final RoomService roomService;

  KickGuestEndpoint({required this.roomService});

  @override
  String get name => 'kickGuest';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    await roomService.kickGuest(params.roomId, uid: request.uid, now: request.receivedAt);
    return null;
  }
}

/// 방장이 대국을 시작한다. 결과: `gameId`. 두 사람의 `player_states.gameId`도 생긴다.
class StartRoomGameEndpoint extends CallableEndpoint {
  final RoomService roomService;

  StartRoomGameEndpoint({required this.roomService});

  @override
  String get name => 'startRoomGame';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    final gameId = await roomService.startRoomGame(params.roomId, uid: request.uid, now: request.receivedAt);
    return {'gameId': gameId};
  }
}
