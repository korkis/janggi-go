import 'dart:math';

import '../config.dart';
import '../firebase/firestore_client.dart';
import '../http/callable.dart';
import '../logging.dart';
import '../models/active_game.dart';
import '../models/game_enums.dart';
import '../models/player_state.dart';
import '../models/quick_queue_entry.dart';
import '../repositories/configs_repository.dart';
import '../repositories/connections_repository.dart';
import '../repositories/player_states_repository.dart';
import '../repositories/quick_queue_repository.dart';
import '../repositories/ratings_repository.dart';
import '../repositories/users_repository.dart';
import '../tasks/task_scheduler.dart';
import 'game_rules.dart';
import 'game_service.dart';
import 'rating_rules.dart';

/// 빠른 대국 대기열과 레이팅 매칭(`docs/server.md`의 빠른 대국).
///
/// 대기열은 Firestore `quick_queue`, 사용자가 대기열에 있다는 표시는 `player_states.quickQueueJoinedAt`이다. 둘은 같은
/// 트랜잭션에서 함께 바꾼다. 상대를 찾으면 [GameService.createGame]이 RTDB에 대국을 만들고, 두 사람이 아직 대기열에 있는지
/// 트랜잭션에서 다시 확인한 뒤 대기열에서 빼고 대국에 묶는다. 그래서 두 요청이 같은 상대를 동시에 골라도 한 대국만 생긴다.
class QuickMatchService {
  /// Firestore 트랜잭션을 시작할 때만 쓴다. 문서 읽기·쓰기는 repository가 한다.
  final FirestoreClient firestore;
  final GameService gameService;
  final QuickQueueRepository quickQueue;
  final PlayerStatesRepository playerStates;
  final RatingsRepository ratings;
  final UsersRepository users;
  final ConnectionsRepository connections;
  final ConfigsRepository configs;
  final TaskScheduler taskScheduler;
  final GameLogger logger;
  final NewGameSettings settings;

  /// 매칭 범위를 넓히는 간격. 운영은 [quickMatchStepInterval]이고 통합 테스트는 짧게 줄인다.
  final Duration stepInterval;
  final Random _random;

  QuickMatchService({
    required this.firestore,
    required this.gameService,
    required this.quickQueue,
    required this.playerStates,
    required this.ratings,
    required this.users,
    required this.connections,
    required this.configs,
    required this.taskScheduler,
    required this.logger,
    required this.settings,
    this.stepInterval = quickMatchStepInterval,
    Random? random,
  }) : _random = random ?? Random();

  /// 한 번의 매칭 시도에서 고른 상대를 다른 요청이 먼저 가져갔을 때 다시 찾는 최대 횟수.
  static const _maxMatchAttempts = 3;

  /// [uid]를 대기열에 넣고 바로 한 번 매칭을 시도한다. 찾으면 새 대국 ID, 못 찾으면 null을 돌려준다.
  ///
  /// 이용 정지 중이면 `sanctioned`, 대기열이 아닌 다른 것(방, 대국, 신청)에 있으면 `busy`로 거절한다. 이미 대기열에 있으면
  /// 기다린 시간을 그대로 두고 매칭만 다시 시도한다. 못 찾으면 범위를 넓혀 다시 찾는 `retryQuickMatch`를 예약한다.
  Future<String?> joinQueue(String uid, {required DateTime now}) async {
    await gameService.checkNotSanctioned(uid, now);
    await gameService.settlePreviousGames([uid], now);
    final rating = (await ratings.getRating(uid))?.rating ?? initialRating;

    final joinedAt = await firestore.runTransaction((transaction) async {
      final (states, entries) = await (
        playerStates.getPlayerStatesInTransaction(transaction, [uid]),
        quickQueue.getEntriesInTransaction(transaction, [uid]),
      ).wait;
      final state = states[uid];
      if (GameService.isBusy(state, ignoreQuickQueue: true)) {
        throw const CallableException.failedPrecondition(GameErrorCode.busy, '이미 방, 대국, 신청 중 하나에 있습니다');
      }
      final entry = entries[uid];
      if (entry != null && state?.quickQueueJoinedAt != null) {
        return entry.joinedAt;
      }
      quickQueue.setEntryInTransaction(transaction, uid, QuickQueueEntry(rating: rating, joinedAt: now));
      playerStates.setPlayerStateInTransaction(transaction, uid, _withQuickQueue(state, joinedAt: now, now: now));
      return now;
    });

    final gameId = await _tryMatch(uid, now);
    if (gameId == null) {
      await _scheduleRetry(uid, joinedAt, now);
    }
    logger.info('joinQuickQueue 성공', {'uid': uid, 'gameId': gameId, 'joinedAt': joinedAt});
    return gameId;
  }

  /// [uid]를 대기열에서 뺀다. 이미 대기열에 없으면 아무것도 하지 않는다. 이미 매칭돼 대국이 있으면 `busy`로 거절한다.
  Future<void> leaveQueue(String uid, {required DateTime now}) async {
    final left = await firestore.runTransaction((transaction) async {
      final states = await playerStates.getPlayerStatesInTransaction(transaction, [uid]);
      final state = states[uid];
      if (state?.gameId != null) {
        throw const CallableException.failedPrecondition(GameErrorCode.busy, '이미 상대를 찾아 대국이 만들어졌습니다');
      }
      if (state?.quickQueueJoinedAt == null) {
        return false;
      }
      quickQueue.deleteEntryInTransaction(transaction, uid);
      playerStates.setPlayerStateInTransaction(transaction, uid, _withQuickQueue(state, joinedAt: null, now: now));
      return true;
    });
    logger.info('leaveQuickQueue 성공', {'uid': uid, 'left': left});
  }

  /// `retryQuickMatch` 예약 작업. [joinedAt]에 대기열에 들어온 [uid]가 아직 기다리고 있으면 넓어진 범위로 다시 찾는다.
  ///
  /// 그새 나갔거나 매칭됐거나 다시 들어왔으면(기다린 시각이 다르다) 아무것도 하지 않는다. 앱이 꺼져 연결이 하나도 없으면
  /// 대기열에서 뺀다. 계속 못 찾으면 [stepInterval] 뒤에 다시 예약한다.
  Future<void> retryMatch(String uid, {required int joinedAt, required DateTime now}) async {
    final entry = await quickQueue.getEntry(uid);
    if (entry == null || entry.joinedAt.millisecondsSinceEpoch != joinedAt) {
      logger.debug('retryQuickMatch 건너뜀: 대기열에 없습니다', {'uid': uid});
      return;
    }
    final userConnections = await connections.getConnections(uid);
    if (!userConnections.any((connection) => connection.online)) {
      await leaveQueue(uid, now: now);
      logger.info('retryQuickMatch 연결이 없어 대기열에서 뺌', {'uid': uid});
      return;
    }
    final gameId = await _tryMatch(uid, now);
    if (gameId == null) {
      await _scheduleRetry(uid, entry.joinedAt, now);
    }
    logger.info('retryQuickMatch 완료', {'uid': uid, 'gameId': gameId});
  }

  /// 대기열의 [uid]에게 맞는 상대를 찾아 대국을 만든다. 찾으면 대국 ID, 없거나 그새 [uid]가 대기열을 떠났으면 null.
  ///
  /// 허용 범위는 두 사람 중 더 오래 기다린 사람의 범위다. 범위 안에서 레이팅 차이가 가장 작은 사람(같으면 더 오래 기다린 사람)을
  /// 고르고, 앱을 화면에 띄워 두지 않은 사람은 건너뛴다.
  Future<String?> _tryMatch(String uid, DateTime now) async {
    for (var attempt = 0; attempt < _maxMatchAttempts; attempt++) {
      final mine = await quickQueue.getEntry(uid);
      if (mine == null) {
        return null;
      }
      final candidates = await quickQueue.getEntriesNear(mine.rating)
        ..remove(uid);
      final opponentUid = await _pickOpponent(mine, candidates, now);
      if (opponentUid == null) {
        return null;
      }
      try {
        return await _createQuickGame(uid, mine, opponentUid, candidates[opponentUid]!, now);
      } on _MatchLost catch (lost) {
        logger.debug('매칭 상대를 다시 찾습니다', {'uid': uid, 'opponentUid': opponentUid, 'lostUid': lost.uid});
        if (lost.uid == uid) {
          return null;
        }
      }
    }
    return null;
  }

  Future<String?> _pickOpponent(QuickQueueEntry mine, Map<String, QuickQueueEntry> candidates, DateTime now) async {
    final myRange = getQuickMatchRange(now.difference(mine.joinedAt), stepInterval: stepInterval);
    final inRange = <String>[];
    for (final MapEntry(key: candidateUid, value: candidate) in candidates.entries) {
      final range = max(myRange, getQuickMatchRange(now.difference(candidate.joinedAt), stepInterval: stepInterval));
      if ((candidate.rating - mine.rating).abs() <= range) {
        inRange.add(candidateUid);
      }
    }
    inRange.sort((a, b) {
      final byDifference = (candidates[a]!.rating - mine.rating).abs().compareTo(
        (candidates[b]!.rating - mine.rating).abs(),
      );
      return byDifference != 0 ? byDifference : candidates[a]!.joinedAt.compareTo(candidates[b]!.joinedAt);
    });
    for (final candidateUid in inRange) {
      final candidateConnections = await connections.getConnections(candidateUid);
      if (candidateConnections.any(isConnectionPresent)) {
        return candidateUid;
      }
    }
    return null;
  }

  /// [uid]와 [opponentUid]의 빠른 대국을 만든다. 둘 중 하나가 그새 대기열을 떠났으면 [_MatchLost]를 던진다.
  Future<String> _createQuickGame(
    String uid,
    QuickQueueEntry mine,
    String opponentUid,
    QuickQueueEntry opponent,
    DateTime now,
  ) async {
    final (profiles, appConfig) = await (users.getUsers([uid, opponentUid]), configs.getAppConfig()).wait;
    final players = <GamePlayer>[];
    for (final playerUid in [uid, opponentUid]) {
      final profile = profiles[playerUid];
      if (profile == null) {
        throw _MatchLost(playerUid);
      }
      players.add(GamePlayer(uid: playerUid, nickname: profile.nickname, rankLevel: profile.rankLevel));
    }
    players.shuffle(_random);
    final game = createActiveGame(
      mode: GameMode.quick,
      rated: true,
      listed: true,
      players: GamePlayers(cho: players[0], han: players[1]),
      timeControl: settings.timeControl,
      disconnectLimitMs: settings.getDisconnectLimitMs(appConfig),
      now: now.millisecondsSinceEpoch,
      rematchBlocked: appConfig.quickRematchLimit <= 0,
    );
    final expected = {uid: mine.joinedAt, opponentUid: opponent.joinedAt};
    final gameId = await gameService.createGame(
      game,
      now: now,
      check: (transaction, states) async {
        final entries = await quickQueue.getEntriesInTransaction(transaction, expected.keys.toList());
        for (final MapEntry(key: playerUid, value: joinedAt) in expected.entries) {
          final state = states[playerUid];
          if (entries[playerUid]?.joinedAt != joinedAt ||
              state?.quickQueueJoinedAt != joinedAt ||
              GameService.isBusy(state, ignoreQuickQueue: true)) {
            throw _MatchLost(playerUid);
          }
        }
        for (final playerUid in expected.keys) {
          quickQueue.deleteEntryInTransaction(transaction, playerUid);
        }
      },
    );
    logger.info('빠른 대국 매칭', {
      'gameId': gameId,
      'uids': [uid, opponentUid],
      'ratingDifference': (mine.rating - opponent.rating).abs(),
    });
    return gameId;
  }

  /// [joinedAt]에 들어온 사람의 다음 범위 넓히기 시각에 `retryQuickMatch`를 예약한다.
  Future<void> _scheduleRetry(String uid, DateTime joinedAt, DateTime now) async {
    final step = now.difference(joinedAt).inMilliseconds ~/ stepInterval.inMilliseconds + 1;
    final runAt = joinedAt.add(stepInterval * step);
    final joinedAtMs = joinedAt.millisecondsSinceEpoch;
    await taskScheduler.schedule(
      TaskName.retryQuickMatch,
      {'uid': uid, 'joinedAt': joinedAtMs, 'eventAt': runAt.millisecondsSinceEpoch},
      runAt: runAt,
      taskId: 'quick-$uid-$joinedAtMs-$step',
    );
  }

  /// [state]에서 대기열 표시만 바꾼 상태. 문서가 없었으면 나머지는 비운다.
  static PlayerState _withQuickQueue(PlayerState? state, {required DateTime? joinedAt, required DateTime now}) {
    return PlayerState(
      roomId: state?.roomId,
      gameId: state?.gameId,
      lastGameId: state?.lastGameId,
      outgoingChallengeId: state?.outgoingChallengeId,
      incomingChallengeId: state?.incomingChallengeId,
      setupDraft: state?.setupDraft,
      lastRankChange: state?.lastRankChange,
      quickQueueJoinedAt: joinedAt,
      updatedAt: now,
    );
  }
}

/// 매칭하려던 [uid]가 그새 대기열을 떠났다(나갔거나 다른 사람과 매칭됐다).
class _MatchLost implements Exception {
  final String uid;

  const _MatchLost(this.uid);
}
