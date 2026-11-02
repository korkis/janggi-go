import '../http/callable.dart';
import '../logging.dart';
import '../models/active_game.dart';
import '../models/game_enums.dart';
import '../repositories/active_games_repository.dart';
import '../repositories/configs_repository.dart';
import '../repositories/connections_repository.dart';
import '../repositories/users_repository.dart';
import 'game_rules.dart';
import 'game_service.dart';
import 'room_service.dart';

/// 결과 화면의 다시 두기와 나가기(`docs/server.md`의 다시 두기).
///
/// 누른 기록은 RTDB `games_active/{gameId}/rematch`에 둔다. 두 쪽이 모두 누르면 그 쓰기에서 새 대국 ID를 정하고, 그 쓰기를
/// 한 요청만 새 대국을 만든다. 두 앱은 `rematch.gameId`를 보고 그 대국에 묶이면 옮겨 간다.
class RematchService {
  final GameService gameService;

  /// 방 대국의 다시 두기에서 새 대국을 방에 묶는다.
  final RoomService roomService;
  final ActiveGamesRepository activeGames;
  final UsersRepository users;
  final ConnectionsRepository connections;
  final ConfigsRepository configs;
  final GameLogger logger;
  final NewGameSettings settings;

  const RematchService({
    required this.gameService,
    required this.roomService,
    required this.activeGames,
    required this.users,
    required this.connections,
    required this.configs,
    required this.logger,
    required this.settings,
  });

  /// [uid]가 [gameId]의 결과 화면에서 다시 두기를 누른다. 새 대국이 정해졌으면 그 ID, 상대를 기다리면 null을 돌려준다.
  ///
  /// 상대가 결과 화면을 나갔거나 앱에 없으면, 또는 빠른 대국의 다시 두기 횟수에 닿았으면 `rematchUnavailable`로 거절한다.
  Future<String?> requestRematch(String gameId, {required String uid, required DateTime now}) async {
    final current = await activeGames.getGame(gameId);
    if (current == null) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '대국이 없습니다');
    }
    final opponentUid = current.meta.players.get(requirePlayerSide(current, uid).opponent).uid;
    final (appConfig, opponentConnections) = await (
      configs.getAppConfig(),
      connections.getConnections(opponentUid),
    ).wait;
    final newGameId = activeGames.createGameId();
    final game = await gameService.updateGame(
      gameId,
      now: now,
      action: (game) => pressRematch(
        game,
        requirePlayerSide(game, uid),
        quickRematchLimit: appConfig.quickRematchLimit,
        opponentPresent: opponentConnections.any(isConnectionPresent),
        newGameId: newGameId,
      ),
    );
    final rematch = game.rematch;
    final rematchGameId = rematch?.gameId;
    if (rematch == null || (rematch.cancelled == true && rematchGameId == null)) {
      throw const CallableException.failedPrecondition(GameErrorCode.rematchUnavailable, '상대가 결과 화면을 나갔습니다');
    }
    if (rematchGameId == newGameId) {
      await _createRematchGame(gameId, game, newGameId, now);
    }
    logger.info('requestRematch 성공', {'gameId': gameId, 'uid': uid, 'rematchGameId': rematchGameId});
    return rematchGameId;
  }

  /// [uid]가 [gameId]의 결과 화면을 나간다. 새 대국이 아직 없으면 다시 두기를 취소한다. 대국이 이미 지워졌으면 아무것도
  /// 하지 않는다.
  Future<void> leaveResult(String gameId, {required String uid, required DateTime now}) async {
    final current = await activeGames.getGame(gameId);
    if (current == null) {
      logger.info('leaveResult 성공: 대국이 없습니다', {'gameId': gameId, 'uid': uid});
      return;
    }
    requirePlayerSide(current, uid);
    final game = await gameService.updateGame(
      gameId,
      now: now,
      action: (game) {
        requirePlayerSide(game, uid);
        return cancelRematch(game);
      },
    );
    logger.info('leaveResult 성공', {'gameId': gameId, 'uid': uid, 'cancelled': game.rematch?.cancelled});
  }

  /// 앞 대국과 같은 조건(방, 접장기, 공개 여부)으로 초와 한을 바꾼 새 대국을 [newGameId]로 만든다. 모든 대국 종류가 같다.
  /// 만들지 못하면 다시 두기를 취소하고 `rematchUnavailable`로 거절한다.
  Future<void> _createRematchGame(String previousGameId, ActiveGame previous, String newGameId, DateTime now) async {
    try {
      // 급수 대국이면 레이팅을 먼저 반영해 새 대국의 급수를 맞추고, 두 사람을 앞 대국에서 푼다. 이미 했으면 아무것도 하지 않는다.
      await gameService.finalizeGame(previousGameId, now: now);
      final meta = previous.meta;
      final uids = [meta.players.cho.uid, meta.players.han.uid];
      final (profiles, appConfig) = await (users.getUsers(uids), configs.getAppConfig()).wait;
      final refreshed = {
        for (final MapEntry(key: uid, value: profile) in profiles.entries)
          if (profile != null) uid: GamePlayer(uid: uid, nickname: profile.nickname, rankLevel: profile.rankLevel),
      };
      final rematchCount = meta.rematchCount + 1;
      final game = createActiveGame(
        mode: meta.mode,
        rated: meta.rated,
        listed: meta.listed,
        players: getRematchPlayers(previous, refreshed),
        timeControl: settings.timeControl,
        disconnectLimitMs: settings.getDisconnectLimitMs(appConfig),
        introMs: settings.matchIntro.inMilliseconds,
        now: now.millisecondsSinceEpoch,
        roomId: meta.roomId,
        handicap: meta.handicap,
        rematchOf: previousGameId,
        rematchCount: rematchCount,
        rematchBlocked: meta.mode == GameMode.quick && rematchCount >= appConfig.quickRematchLimit,
      );
      // 방 대국이면 방이 아직 두 사람의 방이고 기다리는 중인지 확인하고 방을 새 대국으로 바꾼다.
      final roomId = meta.roomId;
      await gameService.createGame(
        game,
        now: now,
        gameId: newGameId,
        check: roomId == null ? null : roomService.bindRoomGame(roomId, gameId: newGameId, uids: uids, now: now),
      );
    } on CallableException catch (error) {
      logger.warning('다시 두기 대국을 만들지 못했습니다', {
        'gameId': previousGameId,
        'rematchGameId': newGameId,
        'code': error.code?.name,
      });
      await gameService.updateGame(previousGameId, now: now, action: failRematch);
      throw const CallableException.failedPrecondition(GameErrorCode.rematchUnavailable, '다시 두기 대국을 만들지 못했습니다');
    }
  }
}
