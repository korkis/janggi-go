import '../http/callable.dart';
import '../http/task_handler.dart';
import '../logging.dart';
import '../services/game_service.dart';
import '../tasks/task_scheduler.dart';

// 대국 하나에 대한 예약 작업들이다(`docs/server.md`의 예약 작업). 본문 모양이 같아 한 파일에 둔다.

/// 대국 예약 작업의 본문.
class GameTaskParams {
  final String gameId;

  /// 작업이 맡은 사건의 시각(밀리초). 예약 시각보다 일찍 불려도 이 시각으로 판정한다. 없으면 null.
  final int? eventAt;

  const GameTaskParams({required this.gameId, required this.eventAt});

  /// 판정 기준 시각. 받은 시각과 [eventAt] 중 늦은 쪽이다. 판정은 기록된 시각으로 하므로 작업이 늦게 돌아도 결과가 같다.
  DateTime getJudgedAt(DateTime receivedAt) {
    final eventAt = this.eventAt;
    if (eventAt == null || receivedAt.millisecondsSinceEpoch >= eventAt) {
      return receivedAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(eventAt, isUtc: true);
  }
}

/// 본문: `gameId`(문자열), `eventAt?`(ms).
GameTaskParams validateParams(Object? requestParams) {
  if (requestParams is! Map<String, Object?>) {
    throw const InvalidTaskPayloadException('본문은 객체여야 합니다');
  }
  final gameId = requestParams['gameId'];
  final eventAt = requestParams['eventAt'];
  if (gameId is! String || gameId.isEmpty) {
    throw const InvalidTaskPayloadException('gameId가 없습니다');
  }
  if (eventAt != null && eventAt is! int) {
    throw const InvalidTaskPayloadException('eventAt은 정수여야 합니다');
  }
  return GameTaskParams(gameId: gameId, eventAt: eventAt as int?);
}

/// 상차림 마감, 시간패 시각, 접속 끊김 마감에 판정을 다시 본다. 대국이 이미 지워졌으면 아무것도 하지 않는다.
class EvaluateGameTaskEndpoint extends TaskEndpoint {
  final GameService gameService;
  final GameLogger logger;

  EvaluateGameTaskEndpoint({required this.gameService, required this.logger});

  @override
  TaskName get name => TaskName.evaluateGame;

  @override
  Future<void> handle(TaskRequest request, Object? payload) async {
    final requestParams = payload;
    final params = validateParams(requestParams);
    try {
      final game = await gameService.updateGame(params.gameId, now: params.getJudgedAt(request.receivedAt));
      logger.info('evaluateGame 완료', {
        'gameId': params.gameId,
        'phase': game.state.phase.name,
        'version': game.state.version,
      });
    } on CallableException catch (error) {
      if (error.code != GameErrorCode.notFound) {
        rethrow;
      }
      logger.info('evaluateGame 건너뜀: 대국이 없습니다', {'gameId': params.gameId});
    }
  }
}

/// 끝난 대국의 기보 저장과 대국자 풀기. 대국이 끝날 때 바로 한 번 실행하고, 실패에 대비해 한 번 더 예약한다.
class FinalizeGameTaskEndpoint extends TaskEndpoint {
  final GameService gameService;

  FinalizeGameTaskEndpoint({required this.gameService});

  @override
  TaskName get name => TaskName.finalizeGame;

  @override
  Future<void> handle(TaskRequest request, Object? payload) async {
    final requestParams = payload;
    final params = validateParams(requestParams);
    await gameService.finalizeGame(params.gameId, now: request.receivedAt);
  }
}

/// 묶이지 않은 대국과 끝난 지 오래된 대국을 RTDB에서 지운다.
class CleanupGameTaskEndpoint extends TaskEndpoint {
  final GameService gameService;

  CleanupGameTaskEndpoint({required this.gameService});

  @override
  TaskName get name => TaskName.cleanupGame;

  @override
  Future<void> handle(TaskRequest request, Object? payload) async {
    final requestParams = payload;
    final params = validateParams(requestParams);
    await gameService.cleanupGame(params.gameId, now: params.getJudgedAt(request.receivedAt));
  }
}
