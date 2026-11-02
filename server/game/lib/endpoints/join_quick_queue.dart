import '../http/callable.dart';
import '../services/quick_match_service.dart';

/// 빠른 대국 대기열에 들어가고 바로 한 번 상대를 찾는다(`docs/server.md`의 빠른 대국). 파라미터는 없다.
///
/// 결과: `gameId`(찾았으면 새 대국, 아니면 null). 앱은 결과와 상관없이 `player_states`를 듣고 대국이 생기면 옮겨 간다.
class JoinQuickQueueEndpoint extends CallableEndpoint {
  final QuickMatchService quickMatchService;

  JoinQuickQueueEndpoint({required this.quickMatchService});

  @override
  String get name => 'joinQuickQueue';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final gameId = await quickMatchService.joinQueue(request.uid, now: request.receivedAt);
    return {'gameId': gameId};
  }
}
