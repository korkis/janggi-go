import '../http/callable.dart';
import '../services/quick_match_service.dart';

/// 빠른 대국 대기열에서 나온다(빠른 대국 대기 화면의 "그만 찾기"). 파라미터는 없다.
///
/// 이미 대기열에 없으면 그대로 성공한다. 그새 상대를 찾아 대국이 만들어졌으면 `busy`로 거절하고, 앱은 그 대국으로 간다.
class LeaveQuickQueueEndpoint extends CallableEndpoint {
  final QuickMatchService quickMatchService;

  LeaveQuickQueueEndpoint({required this.quickMatchService});

  @override
  String get name => 'leaveQuickQueue';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    await quickMatchService.leaveQueue(request.uid, now: request.receivedAt);
    return null;
  }
}
