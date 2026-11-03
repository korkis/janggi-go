import 'package:janggi_core/janggi_core.dart';

import '../config.dart';
import '../firebase/firestore_client.dart';
import '../http/callable.dart';
import '../logging.dart';
import '../models/active_game.dart';
import '../models/app_config.dart';
import '../models/archived_game.dart';
import '../models/connection.dart';
import '../models/game_enums.dart';
import '../models/player_state.dart';
import '../models/rating.dart';
import '../models/spectate_list_entry.dart';
import '../models/user.dart';
import '../models/user_private.dart';
import '../repositories/active_games_repository.dart';
import '../repositories/archived_games_repository.dart';
import '../repositories/connections_repository.dart';
import '../repositories/online_users_repository.dart';
import '../repositories/player_states_repository.dart';
import '../repositories/ratings_repository.dart';
import '../repositories/rooms_repository.dart';
import '../repositories/spectate_list_repository.dart';
import '../repositories/spectators_repository.dart';
import '../repositories/users_private_repository.dart';
import '../repositories/users_repository.dart';
import '../tasks/task_scheduler.dart';
import 'game_rules.dart';
import 'rating_rules.dart';

/// [GameService.updateGame]에 넘기는 대국 변경. 판정 다시 보기를 마친 대국을 받아 바꾼 대국을 돌려준다.
/// 바꿀 수 없으면 [CallableException]을 던진다. RTDB 쓰기가 부딪히면 다시 불리므로 부수 효과를 두지 않는다.
typedef GameAction = ActiveGame Function(ActiveGame game);

/// [GameService.createGame]이 두 대국자를 새 대국에 묶는 트랜잭션 안에서 부르는 확인. [states]는 이미 읽은 두 대국자의
/// 상태다. 더 읽을 것이 있으면 읽고, 묶을 수 없으면 예외를 던진다. 대국자 상태 말고 함께 바꿀 문서가 있으면 여기서 쓴다.
/// 트랜잭션이 다시 실행되면 다시 불린다.
typedef GameBindingCheck = Future<void> Function(FirestoreTransaction transaction, Map<String, PlayerState?> states);

/// 새 대국의 시간 설정. 운영은 `config.dart`와 `configs/app`의 값이고, 통합 테스트는 짧게 줄인다.
class NewGameSettings {
  final TimeControl timeControl;

  /// 접속 끊김 허용 시간 합계. null이면 `configs/app.disconnectLimitSeconds`를 쓴다.
  final Duration? disconnectLimit;

  const NewGameSettings({required this.timeControl, required this.disconnectLimit});

  int getDisconnectLimitMs(AppConfig appConfig) {
    return (disconnectLimit ?? Duration(seconds: appConfig.disconnectLimitSeconds)).inMilliseconds;
  }
}

/// 대국을 만들고, 판정하고, 끝내는 흐름(`docs/server.md`의 대국 진행).
///
/// 대국 상태는 RTDB `games_active`, 대국자 묶기와 기보는 Firestore에 둔다. 시각이 지나서 일어나는 일은 [taskScheduler]로
/// 예약한다.
class GameService {
  /// Firestore 트랜잭션을 시작할 때만 쓴다. 문서 읽기·쓰기는 repository가 한다.
  final FirestoreClient firestore;
  final ActiveGamesRepository activeGames;
  final PlayerStatesRepository playerStates;
  final ArchivedGamesRepository archivedGames;
  final ConnectionsRepository connections;
  final RatingsRepository ratings;
  final UsersRepository users;
  final UsersPrivateRepository usersPrivate;
  final RoomsRepository rooms;
  final OnlineUsersRepository onlineUsers;
  final SpectateListRepository spectateList;
  final SpectatorsRepository spectators;
  final TaskScheduler taskScheduler;
  final GameLogger logger;

  const GameService({
    required this.firestore,
    required this.activeGames,
    required this.playerStates,
    required this.archivedGames,
    required this.connections,
    required this.ratings,
    required this.users,
    required this.usersPrivate,
    required this.rooms,
    required this.onlineUsers,
    required this.spectateList,
    required this.spectators,
    required this.taskScheduler,
    required this.logger,
  });

  /// [game]을 RTDB에 만들고 두 대국자의 `player_states.gameId`에 묶는다. 만든 대국 ID를 돌려준다.
  ///
  /// RTDB에 먼저 쓰고 Firestore 트랜잭션으로 묶는다(`docs/server.md`의 동시에 들어온 요청). [check]가 없으면 한 사람이라도
  /// 이미 대기열, 방, 대국, 신청 중 하나에 있을 때 `busy`로 거절한다. 묶지 못하면 만든 대국을 지우고 그 예외를 다시 던진다.
  /// 묶으면 두 대국자의 대기열 표시(`quickQueueJoinedAt`)와 신청 표시(`outgoingChallengeId`, `incomingChallengeId`)는 지운다.
  /// 신청 표시는 신청을 수락해 만드는 대국에서만 남아 있다([check]가 그 신청을 확인한다). [gameId]를 주면 그 ID로 만든다(다시 두기).
  /// 묶은 뒤 두 사람의 `online_users` 상태를 `playing`으로 바꾼다.
  Future<String> createGame(ActiveGame game, {required DateTime now, String? gameId, GameBindingCheck? check}) async {
    final uids = [game.meta.players.cho.uid, game.meta.players.han.uid];
    await settlePreviousGames(uids, now);

    final newGameId = gameId ?? activeGames.createGameId();
    await activeGames.createGame(newGameId, game);
    try {
      await firestore.runTransaction((transaction) async {
        final states = await playerStates.getPlayerStatesInTransaction(transaction, uids);
        if (check != null) {
          await check(transaction, states);
        } else if (uids.any((uid) => isBusy(states[uid]))) {
          throw const CallableException.failedPrecondition(GameErrorCode.busy, '이미 대국이나 매칭 중인 대국자가 있습니다');
        }
        for (final uid in uids) {
          playerStates.setPlayerStateInTransaction(
            transaction,
            uid,
            _copyPlayerState(
              states[uid],
              gameId: newGameId,
              setupDraft: null,
              quickQueueJoinedAt: null,
              clearChallenges: true,
              now: now,
            ),
          );
        }
      });
    } catch (_) {
      await activeGames.deleteGame(newGameId);
      rethrow;
    }

    await _scheduleEvaluation(newGameId, game);
    final unboundCheckAt = game.meta.createdAt + unboundGameCleanupDelay.inMilliseconds;
    await taskScheduler.schedule(
      TaskName.cleanupGame,
      {'gameId': newGameId, 'eventAt': unboundCheckAt},
      runAt: _fromMs(unboundCheckAt),
      taskId: 'cleanup-created-$newGameId',
    );
    await _updateOnlineStatus(uids, OnlineStatus.playing);
    return newGameId;
  }

  /// 대국 판정을 다시 보고(`docs/server.md`의 판정 다시 보기) [action]을 적용해 RTDB에 쓴다. 쓴 뒤의 대국을 돌려준다.
  ///
  /// [action]이 거절해도 판정 다시 보기로 바뀐 것(예: 시간패)은 쓰고 나서 거절을 던진다. 대국이 없으면 `notFound`.
  Future<ActiveGame> updateGame(String gameId, {required DateTime now, GameAction? action}) async {
    final nowMs = now.millisecondsSinceEpoch;
    final current = await activeGames.getGame(gameId);
    if (current == null) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '대국이 없습니다');
    }
    final (drafts, presence) = await (_getDueSetupDrafts(gameId, current, nowMs), _getPlayerConnections(current)).wait;

    ActiveGame? before;
    CallableException? rejection;
    final written = await activeGames.updateGame(gameId, (game) {
      if (game == null) {
        throw const CallableException.failedPrecondition(GameErrorCode.notFound, '대국이 없습니다');
      }
      before = game;
      rejection = null;
      final evaluated = applyDueEvents(game, nowMs, drafts: drafts, connections: presence);
      var next = evaluated;
      if (action != null) {
        try {
          next = action(evaluated);
        } on CallableException catch (error) {
          rejection = error;
        }
      }
      if (identical(next, game)) {
        return null;
      }
      return next.copyWith(state: next.state.copyWith(version: game.state.version + 1));
    });

    if (written != null) {
      await _onGameWritten(gameId, before!, written, now);
    }
    final error = rejection;
    if (error != null) {
      throw error;
    }
    return written ?? before!;
  }

  /// 상차림 화면에서 골라 둔 것을 `player_states.setupDraft`에 둔다. 상대에게 보이지 않게 RTDB에 쓰지 않는다.
  ///
  /// 먼저 판정을 다시 보고, [uid]가 지금 고를 차례가 아니면 거절한다.
  Future<void> saveSetupDraft(
    String gameId, {
    required String uid,
    required Formation formation,
    required DateTime now,
  }) async {
    final game = await updateGame(gameId, now: now);
    checkCanPickFormation(game, requirePlayerSide(game, uid));
    await playerStates.updateSetupDraft(uid, gameId: gameId, formation: formation, now: now);
  }

  /// 끝난 대국의 기보를 저장하고 두 대국자를 대국에서 푼다(`docs/server.md`의 결과와 레이팅).
  ///
  /// 한 트랜잭션에서 하며 `games_archived/{gameId}`가 이미 있으면 아무것도 하지 않는다. 여러 번 불려도 결과가 같다.
  /// 급수 대국(`meta.rated`)이면 레이팅과 급수도 반영한다. 방 대국이면 방을 `waiting`으로 돌린다. 두 사람의 `roomId`는 그대로
  /// 두므로 결과 화면을 나가면 방 대기실로 돌아온다. 두 사람의 `users.stats`에 이 대국을 더한다. 온라인 대국은 종류와 급수 대국
  /// 여부에 상관없이 모두 센다(`docs/database.md`의 `users`).
  Future<void> finalizeGame(String gameId, {required DateTime now}) async {
    final game = await activeGames.getGame(gameId);
    if (game == null) {
      logger.warning('finalizeGame 건너뜀: 대국이 없습니다', {'gameId': gameId});
      return;
    }
    if (game.state.phase != GamePhase.finished) {
      logger.warning('finalizeGame 건너뜀: 끝나지 않은 대국입니다', {'gameId': gameId, 'phase': game.state.phase.name});
      return;
    }
    final uids = [game.meta.players.cho.uid, game.meta.players.han.uid];
    final rated = game.meta.rated;
    final archived = await firestore.runTransaction((transaction) async {
      if (await archivedGames.hasArchivedGameInTransaction(transaction, gameId)) {
        return false;
      }
      final roomId = game.meta.roomId;
      final (states, room, profiles) = await (
        playerStates.getPlayerStatesInTransaction(transaction, uids),
        roomId == null ? Future.value(null) : rooms.getRoomInTransaction(transaction, roomId),
        users.getUsersInTransaction(transaction, uids),
      ).wait;
      if (roomId != null && room != null && room.gameId == gameId && room.status == RoomStatus.playing) {
        rooms.updateStatusInTransaction(transaction, roomId, status: RoomStatus.waiting, now: now);
      }
      final rankChanges = rated
          ? await _applyRatingsInTransaction(transaction, gameId, game, now)
          : const <String, RankChange>{};
      archivedGames.createArchivedGameInTransaction(transaction, gameId, _buildArchivedGame(game));
      _updateRecordsInTransaction(transaction, gameId, game, profiles, rankChanges);
      for (final uid in uids) {
        final state = states[uid];
        final draft = state?.setupDraft;
        playerStates.setPlayerStateInTransaction(
          transaction,
          uid,
          _copyPlayerState(
            state,
            gameId: state?.gameId == gameId ? null : state?.gameId,
            lastGameId: gameId,
            setupDraft: draft?.gameId == gameId ? null : draft,
            quickQueueJoinedAt: state?.quickQueueJoinedAt,
            lastRankChange: rankChanges[uid],
            now: now,
          ),
        );
      }
      return true;
    });
    if (archived) {
      await _updateOnlineStatus(uids, OnlineStatus.waiting);
    }
    logger.info('finalizeGame 완료', {
      'gameId': gameId,
      'archived': archived,
      'rated': rated,
      'reason': game.state.result?.reason.name,
    });
  }

  /// 두 대국자의 `users`에 전적과, 급수 대국이면 바뀐 급수를 쓴다. 프로필이 없는 사용자는 건너뛴다.
  void _updateRecordsInTransaction(
    FirestoreTransaction transaction,
    String gameId,
    ActiveGame game,
    Map<String, User?> profiles,
    Map<String, RankChange> rankChanges,
  ) {
    final winner = game.state.result!.winner;
    for (final side in Side.values) {
      final uid = game.meta.players.get(side).uid;
      final profile = profiles[uid];
      if (profile == null) {
        logger.warning('users가 없어 전적을 쓰지 않습니다', {'uid': uid, 'gameId': gameId});
        continue;
      }
      final won = side == winner;
      final stats = profile.stats;
      users.updateRecordInTransaction(
        transaction,
        uid,
        stats: UserStats(
          games: stats.games + 1,
          wins: stats.wins + (won ? 1 : 0),
          losses: stats.losses + (won ? 0 : 1),
        ),
        rankLevel: rankChanges[uid]?.rankLevelAfter,
      );
    }
  }

  /// 급수 대국의 결과로 두 대국자의 레이팅과 급수 진행을 바꾼다(`docs/server.md`의 결과와 레이팅). 바뀐 급수는
  /// [_updateRecordsInTransaction]이 전적과 함께 쓴다. 트랜잭션의 읽기를 먼저 하고 쓰기를 모은다. uid별 급수 변동을 돌려준다.
  Future<Map<String, RankChange>> _applyRatingsInTransaction(
    FirestoreTransaction transaction,
    String gameId,
    ActiveGame game,
    DateTime now,
  ) async {
    final players = game.meta.players;
    final uids = [players.cho.uid, players.han.uid];
    final (before, privateExists) = await (
      ratings.getRatingsInTransaction(transaction, uids),
      usersPrivate.hasUsersPrivateInTransaction(transaction, uids),
    ).wait;
    final winner = game.state.result!.winner;
    final changes = <String, RankChange>{};
    for (final side in Side.values) {
      final uid = players.get(side).uid;
      final mine = before[uid];
      final rating = mine?.rating ?? initialRating;
      final outcome = getRatedOutcome(
        rating: rating,
        ratedGames: mine?.ratedGames ?? 0,
        opponentRating: before[players.get(side.opponent).uid]?.rating ?? initialRating,
        won: side == winner,
      );
      ratings.setRatingInTransaction(
        transaction,
        uid,
        Rating(rating: outcome.rating, ratedGames: outcome.ratedGames, updatedAt: now),
      );
      if (privateExists[uid] == true) {
        usersPrivate.updateRankProgressInTransaction(
          transaction,
          uid,
          rankProgress: outcome.rankProgress,
          winsToNextRank: outcome.winsToNextRank,
        );
      } else {
        // Functions가 프로필과 함께 만드는 문서다. 없어도 대국 마무리는 막지 않는다.
        logger.warning('users_private가 없어 급수 진행을 쓰지 않습니다', {'uid': uid, 'gameId': gameId});
      }
      changes[uid] = RankChange(
        gameId: gameId,
        rankLevelBefore: getRankLevel(rating),
        rankLevelAfter: outcome.rankLevel,
        rankProgressBefore: getRankProgress(rating),
        rankProgressAfter: outcome.rankProgress,
      );
    }
    return changes;
  }

  /// 묶이지 않은 대국과 끝난 지 [finishedGameRetentionMinutes]가 지난 대국을 RTDB에서 지운다.
  ///
  /// 끝난 대국은 기보를 저장한 뒤에만 지운다. 아직 저장 전이면 오류를 던져 예약 작업이 다시 부르게 한다.
  Future<void> cleanupGame(String gameId, {required DateTime now}) async {
    final game = await activeGames.getGame(gameId);
    if (game == null) {
      return;
    }
    final nowMs = now.millisecondsSinceEpoch;
    final endedAt = game.state.endedAt;
    if (game.state.phase == GamePhase.finished && endedAt != null) {
      if (nowMs < endedAt + const Duration(minutes: finishedGameRetentionMinutes).inMilliseconds) {
        return;
      }
      if (!await archivedGames.hasArchivedGame(gameId)) {
        throw StateError('기보를 저장하기 전이라 지우지 않습니다: $gameId');
      }
      await activeGames.deleteGame(gameId);
      await _deleteSpectateData(gameId);
      logger.info('cleanupGame 끝난 대국 지움', {'gameId': gameId});
      return;
    }
    if (nowMs < game.meta.createdAt + unboundGameCleanupDelay.inMilliseconds) {
      return;
    }
    final uids = [game.meta.players.cho.uid, game.meta.players.han.uid];
    final states = await playerStates.getPlayerStates(uids);
    if (uids.any((uid) => states[uid]?.gameId == gameId)) {
      return;
    }
    await activeGames.deleteGame(gameId);
    await _deleteSpectateData(gameId);
    logger.info('cleanupGame 묶이지 않은 대국 지움', {'gameId': gameId});
  }

  /// [uids]가 묶인 대국 중 이미 끝났어야 하는 것(예: 시간패 예약 작업이 돌지 못한 대국)을 판정하고, 끝났으면 기보를 저장해
  /// 대국자를 푼다. 새 대국이나 대기열에 넣기 전에 부른다.
  Future<void> settlePreviousGames(List<String> uids, DateTime now) async {
    final states = await playerStates.getPlayerStates(uids);
    for (final uid in uids) {
      final gameId = states[uid]?.gameId;
      if (gameId == null) {
        continue;
      }
      try {
        final game = await updateGame(gameId, now: now);
        if (game.state.phase == GamePhase.finished) {
          await finalizeGame(gameId, now: now);
        }
      } on CallableException catch (error) {
        logger.warning('이전 대국을 판정하지 못했습니다', {'uid': uid, 'gameId': gameId, 'code': error.code?.name});
      }
    }
  }

  /// 이용 정지나 영구 정지 중이면 `sanctioned`로 거절한다(`docs/server.md`의 대국 서버와 Functions의 경계). 대기열과 방을
  /// 시작할 때 부른다.
  Future<void> checkNotSanctioned(String uid, DateTime now) async {
    final sanction = (await usersPrivate.getUserPrivate(uid))?.sanction;
    if (sanction == null) {
      return;
    }
    final endsAt = sanction.endsAt;
    final blocking = switch (sanction.type) {
      SanctionType.permanentBan => true,
      SanctionType.suspension => endsAt == null || endsAt.isAfter(now),
      SanctionType.warning || SanctionType.chatRestriction => false,
    };
    if (blocking) {
      throw const CallableException.failedPrecondition(GameErrorCode.sanctioned, '이용이 제한된 사용자입니다');
    }
  }

  /// 대국실에 있는 [uids]의 `online_users` 상태를 바꾼다. 대국 상태를 쓴 뒤에 따라 쓰는 표시이므로 실패해도 대국을 막지 않는다.
  /// 앱이 다음에 `enterLobby`를 부를 때 다시 맞춰진다.
  Future<void> _updateOnlineStatus(List<String> uids, OnlineStatus status) async {
    for (final uid in uids) {
      try {
        await onlineUsers.updateStatus(uid, status);
      } catch (error, stackTrace) {
        logger.error(
          'online_users 상태를 바꾸지 못했습니다',
          fields: {'uid': uid, 'status': status.name},
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// 상차림 마감이 지났으면 두 대국자가 골라 둔 상차림. 마감 전이면 읽지 않는다.
  Future<Map<Side, Formation>> _getDueSetupDrafts(String gameId, ActiveGame game, int nowMs) async {
    if (game.state.phase != GamePhase.setup || nowMs < game.state.setup.deadlineAt) {
      return const {};
    }
    final players = game.meta.players;
    final states = await playerStates.getPlayerStates([players.cho.uid, players.han.uid]);
    final drafts = <Side, Formation>{};
    for (final side in Side.values) {
      final draft = states[players.get(side).uid]?.setupDraft;
      if (draft != null && draft.gameId == gameId) {
        drafts[side] = draft.formation;
      }
    }
    return drafts;
  }

  /// 두 대국자의 접속 상태(`connections`). 끝난 대국이면 읽지 않는다.
  Future<Map<Side, List<Connection>>> _getPlayerConnections(ActiveGame game) async {
    if (game.state.phase == GamePhase.finished) {
      return const {};
    }
    final players = game.meta.players;
    final (cho, han) = await (
      connections.getConnections(players.cho.uid),
      connections.getConnections(players.han.uid),
    ).wait;
    return {Side.cho: cho, Side.han: han};
  }

  /// RTDB에 쓴 뒤의 일. 끝났으면 기보 저장과 정리를 예약하고 바로 한 번 저장한다. 아니면 다음 판정을 예약한다.
  Future<void> _onGameWritten(String gameId, ActiveGame before, ActiveGame after, DateTime now) async {
    await _updateSpectateList(gameId, before, after);
    final endedAt = after.state.endedAt;
    if (before.state.phase == GamePhase.finished || after.state.phase != GamePhase.finished || endedAt == null) {
      await _scheduleEvaluation(gameId, after);
      return;
    }
    logger.info('대국 끝남', {
      'gameId': gameId,
      'winner': after.state.result?.winner.name,
      'reason': after.state.result?.reason.name,
      'moves': after.moves.length,
    });
    await taskScheduler.schedule(
      TaskName.finalizeGame,
      {'gameId': gameId},
      runAt: now.add(finalizeGameRetryDelay),
      taskId: 'finalize-$gameId',
    );
    final removeAt = endedAt + const Duration(minutes: finishedGameRetentionMinutes).inMilliseconds;
    await taskScheduler.schedule(
      TaskName.cleanupGame,
      {'gameId': gameId, 'eventAt': removeAt},
      runAt: _fromMs(removeAt),
      taskId: 'cleanup-finished-$gameId',
    );
    try {
      await finalizeGame(gameId, now: now);
    } catch (error, stackTrace) {
      // 예약한 finalizeGame이 다시 실행한다.
      logger.error('finalizeGame 바로 실행 실패', fields: {'gameId': gameId}, error: error, stackTrace: stackTrace);
    }
  }

  /// 관전 목록 카드를 대국에 맞춘다(`docs/server.md`의 수, 관전자 수). 공개 대국(`meta.listed`)이 상차림을 마쳐 진행 중이면
  /// 지금 국면, 수, 관전자 수로 쓰고, 끝나면 지운다. 상차림 중에는 국면이 없어 올리지 않는다. 대국 상태를 쓴 뒤에 따라 쓰는
  /// 표시이므로 실패해도 대국을 막지 않고 다음 쓰기에서 다시 맞춘다.
  Future<void> _updateSpectateList(String gameId, ActiveGame before, ActiveGame after) async {
    if (!after.meta.listed) {
      return;
    }
    try {
      if (after.state.phase == GamePhase.finished) {
        if (before.state.phase != GamePhase.finished) {
          await spectateList.deleteEntry(gameId);
        }
        return;
      }
      if (after.state.phase != GamePhase.playing) {
        return;
      }
      final players = after.meta.players;
      final spectatorCount = await spectators.countSpectators(gameId);
      await spectateList.setEntry(
        gameId,
        SpectateListEntry(
          players: SpectatePlayers(
            cho: SpectatePlayer(nickname: players.cho.nickname, rankLevel: players.cho.rankLevel),
            han: SpectatePlayer(nickname: players.han.nickname, rankLevel: players.han.rankLevel),
          ),
          fen: replayGame(after).position.fen,
          moveCount: after.moves.length,
          handicapped: after.meta.handicap?.isNotEmpty ?? false,
          spectatorCount: spectatorCount,
          startedAt: after.state.setup.startsAt,
        ),
      );
    } catch (error, stackTrace) {
      logger.error('spectate_list를 쓰지 못했습니다', fields: {'gameId': gameId}, error: error, stackTrace: stackTrace);
    }
  }

  /// RTDB에서 지운 대국의 관전 목록 카드와 관전자 표시를 지운다. 실패해도 대국 정리는 막지 않는다.
  Future<void> _deleteSpectateData(String gameId) async {
    try {
      await (spectateList.deleteEntry(gameId), spectators.deleteSpectators(gameId)).wait;
    } catch (error, stackTrace) {
      logger.error('관전 데이터를 지우지 못했습니다', fields: {'gameId': gameId}, error: error, stackTrace: stackTrace);
    }
  }

  /// 다음 사건(상차림 마감, 시간패, 접속 끊김 마감) 시각에 `evaluateGame`을 예약한다. 같은 사건은 한 번만 예약한다.
  Future<void> _scheduleEvaluation(String gameId, ActiveGame game) async {
    final eventAt = getNextEventAt(game);
    if (eventAt == null) {
      return;
    }
    await taskScheduler.schedule(
      TaskName.evaluateGame,
      {'gameId': gameId, 'eventAt': eventAt},
      runAt: _fromMs(eventAt),
      taskId: 'evaluate-$gameId-$eventAt',
    );
  }

  ArchivedGame _buildArchivedGame(ActiveGame game) {
    final meta = game.meta;
    final state = game.state;
    final players = meta.players;
    final uids = [players.cho.uid, players.han.uid];
    return ArchivedGame(
      mode: meta.mode,
      rated: meta.rated,
      roomId: meta.roomId,
      playerUids: uids,
      pairKey: ([...uids]..sort()).join('_'),
      players: ArchivedPlayers(
        cho: ArchivedPlayer(uid: players.cho.uid, rankLevel: players.cho.rankLevel),
        han: ArchivedPlayer(uid: players.han.uid, rankLevel: players.han.rankLevel),
      ),
      handicap: meta.handicap,
      timeControl: meta.timeControl,
      initialFen: getInitialPosition(game).fen,
      moves: [for (final move in game.moves) move.m],
      moveTimesMs: [for (final move in game.moves) move.spentMs],
      result: state.result!,
      rematchOf: meta.rematchOf,
      startedAt: _fromMs(state.setup.startsAt),
      endedAt: _fromMs(state.endedAt!),
    );
  }

  /// 이미 대기열, 방, 대국, 신청 중 하나에 있다. [ignoreQuickQueue]면 대기열에 있는 것은 빼고 본다.
  static bool isBusy(PlayerState? state, {bool ignoreQuickQueue = false}) {
    if (state == null) {
      return false;
    }
    return state.gameId != null ||
        state.roomId != null ||
        (!ignoreQuickQueue && state.quickQueueJoinedAt != null) ||
        state.outgoingChallengeId != null ||
        state.incomingChallengeId != null;
  }

  /// [state]에서 대국과 대기열 필드만 바꾼 상태. [clearChallenges]면 신청 표시도 지운다. 문서가 없었으면 나머지는 비운다.
  static PlayerState _copyPlayerState(
    PlayerState? state, {
    required String? gameId,
    String? lastGameId,
    required SetupDraft? setupDraft,
    required DateTime? quickQueueJoinedAt,
    RankChange? lastRankChange,
    bool clearChallenges = false,
    required DateTime now,
  }) {
    return PlayerState(
      roomId: state?.roomId,
      gameId: gameId,
      lastGameId: lastGameId ?? state?.lastGameId,
      outgoingChallengeId: clearChallenges ? null : state?.outgoingChallengeId,
      incomingChallengeId: clearChallenges ? null : state?.incomingChallengeId,
      setupDraft: setupDraft,
      lastRankChange: lastRankChange ?? state?.lastRankChange,
      quickQueueJoinedAt: quickQueueJoinedAt,
      updatedAt: now,
    );
  }

  static DateTime _fromMs(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
