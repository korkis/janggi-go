import '../http/task_handler.dart';
import '../services/room_service.dart';
import '../tasks/task_scheduler.dart';

/// `checkRoom` 본문.
class CheckRoomParams {
  final String roomId;

  /// 확인하는 시각(밀리초). 예약 시각보다 일찍 불려도 이 시각으로 센다.
  final int eventAt;

  const CheckRoomParams({required this.roomId, required this.eventAt});

  /// 판정 기준 시각. 받은 시각과 [eventAt] 중 늦은 쪽이다.
  DateTime getJudgedAt(DateTime receivedAt) {
    if (receivedAt.millisecondsSinceEpoch >= eventAt) {
      return receivedAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(eventAt, isUtc: true);
  }
}

/// 본문: `roomId`(문자열), `eventAt`(ms).
CheckRoomParams validateParams(Object? requestParams) {
  if (requestParams is! Map<String, Object?>) {
    throw const InvalidTaskPayloadException('본문은 객체여야 합니다');
  }
  final roomId = requestParams['roomId'];
  final eventAt = requestParams['eventAt'];
  if (roomId is! String || roomId.isEmpty) {
    throw const InvalidTaskPayloadException('roomId가 없습니다');
  }
  if (eventAt is! int) {
    throw const InvalidTaskPayloadException('eventAt은 정수여야 합니다');
  }
  return CheckRoomParams(roomId: roomId, eventAt: eventAt);
}

/// 방이 열려 있는 동안 방장과 상대의 연결을 확인한다. 오래 없으면 방을 닫거나 자리를 비운다.
class CheckRoomTaskEndpoint extends TaskEndpoint {
  final RoomService roomService;

  CheckRoomTaskEndpoint({required this.roomService});

  @override
  TaskName get name => TaskName.checkRoom;

  @override
  Future<void> handle(TaskRequest request, Object? payload) async {
    final requestParams = payload;
    final params = validateParams(requestParams);
    await roomService.checkRoom(params.roomId, now: params.getJudgedAt(request.receivedAt));
  }
}
