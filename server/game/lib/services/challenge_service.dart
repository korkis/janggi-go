import 'dart:math';

import 'package:janggi_core/janggi_core.dart';

import '../config.dart';
import '../firebase/firestore_client.dart';
import '../http/callable.dart';
import '../logging.dart';
import '../models/active_game.dart';
import '../models/challenge.dart';
import '../models/challenge_limit.dart';
import '../models/game_enums.dart';
import '../models/player_state.dart';
import '../models/room.dart';
import '../models/user.dart';
import '../repositories/active_games_repository.dart';
import '../repositories/challenge_limits_repository.dart';
import '../repositories/challenges_repository.dart';
import '../repositories/configs_repository.dart';
import '../repositories/online_users_repository.dart';
import '../repositories/player_states_repository.dart';
import '../repositories/quick_queue_repository.dart';
import '../repositories/rooms_repository.dart';
import '../repositories/user_blocks_repository.dart';
import '../repositories/users_private_repository.dart';
import '../repositories/users_repository.dart';
import '../tasks/task_scheduler.dart';
import 'game_rules.dart';
import 'game_service.dart';

/// 신청할 때 보내는 사람이 정하는 조건(`docs/screens.md`의 대국 신청).
class ChallengeOptions {
  /// 보내는 사람의 진영. 접장기면 떼는 쪽이 한이므로 null이다. 방 초대면 방 조건을 쓰므로 null이다.
  final SideChoice? senderSide;

  /// 접장기 조건. `remover`는 보내는 사람 기준이다. 방 초대면 방 조건을 쓰므로 null이다.
  final RoomHandicap? handicap;

  /// 방 대기실의 접속자 초대면 그 방. 보내는 사람이 방장이어야 한다.
  final String? roomId;

  const ChallengeOptions({required this.senderSide, required this.handicap, required this.roomId});
}

/// [ChallengeService.respondChallenge]의 결과. 수락해서 만든 대국 또는 들어간 방이다. 거절이면 둘 다 null.
typedef ChallengeResponse = ({String? gameId, String? roomId});

/// 대국 신청 보내기, 받기, 수락, 거절, 취소, 응답 마감과 연속 거절 제한(`docs/server.md`의 신청).
///
/// 신청은 Firestore `challenges`, 사람이 신청 중이라는 표시는 보내는 사람의 `player_states.outgoingChallengeId`와 받는 사람의
/// `incomingChallengeId`다. 셋은 같은 트랜잭션에서 함께 바꾼다. 받는 사람이 보내는 사람을 차단했으면 받는 사람의 표시를 쓰지 않아
/// 받는 사람에게 전달하지 않는다. 보내는 사람에게는 응답이 없는 것과 같이 보이고 응답 마감에 `expired`가 된다.
/// 수락하면 [GameService.createGame]이 두 사람을 대국에 묶는 트랜잭션에서 신청을 `accepted`로 바꾼다. 방 초대면 받는 사람을 방에
/// 앉힌다.
class ChallengeService {
  /// Firestore 트랜잭션을 시작할 때만 쓴다. 문서 읽기·쓰기는 repository가 한다.
  final FirestoreClient firestore;
  final GameService gameService;
  final ChallengesRepository challenges;
  final ChallengeLimitsRepository challengeLimits;
  final UserBlocksRepository userBlocks;
  final OnlineUsersRepository onlineUsers;
  final PlayerStatesRepository playerStates;
  final RoomsRepository rooms;
  final QuickQueueRepository quickQueue;
  final ActiveGamesRepository activeGames;
  final UsersRepository users;
  final UsersPrivateRepository usersPrivate;
  final ConfigsRepository configs;
  final TaskScheduler taskScheduler;
  final GameLogger logger;
  final NewGameSettings settings;

  /// 신청에 응답할 수 있는 시간. 운영은 [challengeResponseSeconds]이고 통합 테스트는 짧게 줄인다.
  final Duration responseTime;

  /// 연속 거절 제한에 닿았을 때 같은 상대에게 신청할 수 없는 시간. 운영은 [challengeBlockMinutes]다.
  final Duration blockTime;
  final Random _random;

  ChallengeService({
    required this.firestore,
    required this.gameService,
    required this.challenges,
    required this.challengeLimits,
    required this.userBlocks,
    required this.onlineUsers,
    required this.playerStates,
    required this.rooms,
    required this.quickQueue,
    required this.activeGames,
    required this.users,
    required this.usersPrivate,
    required this.configs,
    required this.taskScheduler,
    required this.logger,
    required this.settings,
    this.responseTime = const Duration(seconds: challengeResponseSeconds),
    this.blockTime = const Duration(minutes: challengeBlockMinutes),
    Random? random,
  }) : _random = random ?? Random();

  /// [uid]가 [toUid]에게 대국을 신청하고 신청 ID를 돌려준다. 응답 마감에 `expireChallenge`를 예약한다.
  ///
  /// 이용 정지 중이면 `sanctioned`, 이미 대기열·방·대국·신청 중 하나에 있으면 `busy`(방 초대면 그 방의 방장이어야 한다),
  /// 이 상대에게 연속 거절 제한이 걸렸으면 `challengeLimited`, 상대가 대국실에 없거나 신청 받기를 껐거나 다른 일(방, 대국, 신청)을
  /// 하고 있으면 `targetUnavailable`이다. 내가 차단한 상대도 `targetUnavailable`이다. 상대가 빠른 대국 대기열에 있는 것은 괜찮고
  /// 수락할 때 대기열에서 뺀다.
  Future<String> sendChallenge(
    String uid,
    User user,
    String toUid,
    ChallengeOptions options, {
    required DateTime now,
  }) async {
    await gameService.checkNotSanctioned(uid, now);
    await gameService.settlePreviousGames([uid, toUid], now);
    final (targetPrivate, targetOnline, blockedByTarget, blockingTarget, limit) = await (
      usersPrivate.getUserPrivate(toUid),
      onlineUsers.getOnlineUser(toUid),
      userBlocks.hasBlock(toUid, uid),
      userBlocks.hasBlock(uid, toUid),
      challengeLimits.getLimit(uid, toUid),
    ).wait;
    final blockedUntil = limit?.blockedUntil;
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      throw const CallableException.failedPrecondition(GameErrorCode.challengeLimited, '이 상대에게는 지금 신청할 수 없습니다');
    }
    if (blockingTarget || targetOnline == null || targetPrivate?.challengesEnabled != true) {
      throw const CallableException.failedPrecondition(GameErrorCode.targetUnavailable, '상대가 신청을 받을 수 없습니다');
    }

    final roomId = options.roomId;
    final challengeId = challenges.createChallengeId();
    final expiresAt = now.add(responseTime);
    await firestore.runTransaction((transaction) async {
      final (states, room) = await (
        playerStates.getPlayerStatesInTransaction(transaction, [uid, toUid]),
        roomId == null ? Future<Room?>.value() : rooms.getRoomInTransaction(transaction, roomId),
      ).wait;
      final sender = states[uid];
      final target = states[toUid];
      if (roomId == null) {
        if (GameService.isBusy(sender)) {
          throw const CallableException.failedPrecondition(GameErrorCode.busy, '이미 대기열, 방, 대국, 신청 중 하나에 있습니다');
        }
      } else {
        _checkCanInvite(room, roomId, uid: uid, sender: sender, toUid: toUid);
      }
      if (!_isAvailableTarget(target)) {
        throw const CallableException.failedPrecondition(GameErrorCode.targetUnavailable, '상대가 다른 일을 하고 있습니다');
      }
      final handicap = room?.handicap ?? options.handicap;
      challenges.createChallengeInTransaction(
        transaction,
        challengeId,
        Challenge(
          fromUid: uid,
          from: RoomPlayer(nickname: user.nickname, rankLevel: user.rankLevel),
          toUid: toUid,
          roomId: roomId,
          senderSide: handicap != null ? null : (room?.hostSide ?? options.senderSide),
          handicap: handicap,
          timeControl: settings.timeControl,
          status: ChallengeStatus.pending,
          expiresAt: expiresAt,
          gameId: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      playerStates.setPlayerStateInTransaction(
        transaction,
        uid,
        _copyState(
          sender,
          outgoingChallengeId: challengeId,
          incomingChallengeId: sender?.incomingChallengeId,
          now: now,
        ),
      );
      // 받는 사람이 차단했으면 표시를 쓰지 않아 받는 사람의 앱에 팝업이 뜨지 않는다.
      if (!blockedByTarget) {
        playerStates.setPlayerStateInTransaction(
          transaction,
          toUid,
          _copyState(
            target,
            outgoingChallengeId: target?.outgoingChallengeId,
            incomingChallengeId: challengeId,
            now: now,
          ),
        );
      }
    });
    await taskScheduler.schedule(
      TaskName.expireChallenge,
      {'challengeId': challengeId, 'eventAt': expiresAt.millisecondsSinceEpoch},
      runAt: expiresAt,
      taskId: 'challenge-$challengeId',
    );
    logger.info('sendChallenge 성공', {
      'challengeId': challengeId,
      'uid': uid,
      'toUid': toUid,
      'roomId': roomId,
      'delivered': !blockedByTarget,
    });
    return challengeId;
  }

  /// 받은 사람 [uid]가 [challengeId]에 응답한다. 수락하면 대국을 만들거나(방 초대면 방에 앉히고) 그 대국 또는 방을 돌려준다.
  ///
  /// 신청이 없거나, 내가 받은 신청이 아니거나, 이미 끝났거나 응답 마감이 지났으면 `notFound`다. 수락하는데 이용 정지 중이면
  /// `sanctioned`, 초대한 방이 닫혔으면 `roomClosed`, 방에 그새 다른 사람이 들어왔으면 `roomFull`이고 이때 신청은 `cancelled`가 된다.
  /// 거절과 응답 마감은 연속 거절 횟수를 세고, 수락은 횟수를 0으로 돌린다.
  Future<ChallengeResponse> respondChallenge(
    String challengeId, {
    required String uid,
    required User user,
    required bool accepted,
    required DateTime now,
  }) async {
    final challenge = await challenges.getChallenge(challengeId);
    if (challenge == null || challenge.toUid != uid || challenge.status != ChallengeStatus.pending) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '응답할 신청이 없습니다');
    }
    if (!now.isBefore(challenge.expiresAt)) {
      await expireChallenge(challengeId, now: now);
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '응답 시간이 지났습니다');
    }
    if (!accepted) {
      final closed = await _closeChallenge(challengeId, ChallengeStatus.declined, now: now);
      logger.info('respondChallenge 거절', {'challengeId': challengeId, 'uid': uid, 'closed': closed});
      return (gameId: null, roomId: null);
    }
    await gameService.checkNotSanctioned(uid, now);
    final roomId = challenge.roomId;
    if (roomId != null) {
      await _acceptRoomInvite(challengeId, challenge, roomId, user: user, now: now);
      logger.info('respondChallenge 방 초대 수락', {'challengeId': challengeId, 'uid': uid, 'roomId': roomId});
      return (gameId: null, roomId: roomId);
    }
    final gameId = await _acceptGame(challengeId, challenge, now: now);
    logger.info('respondChallenge 수락', {'challengeId': challengeId, 'uid': uid, 'gameId': gameId});
    return (gameId: gameId, roomId: null);
  }

  /// 보낸 사람 [uid]가 [challengeId]를 취소한다. 이미 끝난 신청이면 그대로 성공한다. 연속 거절 횟수는 세지 않는다.
  /// 내가 보낸 신청이 아니면 `notFound`다.
  Future<void> cancelChallenge(String challengeId, {required String uid, required DateTime now}) async {
    final challenge = await challenges.getChallenge(challengeId);
    if (challenge == null || challenge.fromUid != uid) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '취소할 신청이 없습니다');
    }
    final closed = await _closeChallenge(challengeId, ChallengeStatus.cancelled, now: now);
    logger.info('cancelChallenge 성공', {'challengeId': challengeId, 'uid': uid, 'closed': closed});
  }

  /// `expireChallenge` 예약 작업. 응답 마감이 지났는데 아직 응답이 없으면 `expired`로 바꾸고 연속 거절 횟수를 센다.
  /// 이미 끝났거나 마감 전이면 아무것도 하지 않는다.
  Future<void> expireChallenge(String challengeId, {required DateTime now}) async {
    final closed = await _closeChallenge(challengeId, ChallengeStatus.expired, now: now);
    logger.info('expireChallenge 완료', {'challengeId': challengeId, 'closed': closed});
  }

  /// 신청을 수락해 대국을 만든다. 진영은 접장기면 떼는 쪽이 한이고, 아니면 보낸 사람이 고른 진영이다(무작위면 여기서 정한다).
  Future<String> _acceptGame(String challengeId, Challenge challenge, {required DateTime now}) async {
    final fromUid = challenge.fromUid;
    final toUid = challenge.toUid;
    final (profiles, appConfig) = await (users.getUsers([fromUid, toUid]), configs.getAppConfig()).wait;
    final senderProfile = profiles[fromUid];
    final targetProfile = profiles[toUid];
    if (senderProfile == null || targetProfile == null) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '대국자의 프로필이 없습니다');
    }
    final sender = GamePlayer(uid: fromUid, nickname: senderProfile.nickname, rankLevel: senderProfile.rankLevel);
    final target = GamePlayer(uid: toUid, nickname: targetProfile.nickname, rankLevel: targetProfile.rankLevel);
    final senderSide = _getSenderSide(challenge);
    final game = createActiveGame(
      mode: GameMode.challenge,
      rated: false,
      listed: true,
      players: senderSide == Side.cho ? GamePlayers(cho: sender, han: target) : GamePlayers(cho: target, han: sender),
      timeControl: settings.timeControl,
      disconnectLimitMs: settings.getDisconnectLimitMs(appConfig),
      now: now.millisecondsSinceEpoch,
      handicap: challenge.handicap?.pieces,
    );
    final gameId = activeGames.createGameId();
    await gameService.createGame(
      game,
      now: now,
      gameId: gameId,
      check: (transaction, states) async {
        final current = await challenges.getChallengeInTransaction(transaction, challengeId);
        if (current == null || current.status != ChallengeStatus.pending || !now.isBefore(current.expiresAt)) {
          throw const CallableException.failedPrecondition(GameErrorCode.notFound, '응답할 신청이 없습니다');
        }
        final senderState = states[fromUid];
        final targetState = states[toUid];
        if (senderState?.outgoingChallengeId != challengeId || targetState?.incomingChallengeId != challengeId) {
          throw const CallableException.failedPrecondition(GameErrorCode.notFound, '응답할 신청이 없습니다');
        }
        if (senderState?.gameId != null ||
            senderState?.roomId != null ||
            senderState?.quickQueueJoinedAt != null ||
            targetState?.gameId != null ||
            targetState?.roomId != null) {
          throw const CallableException.failedPrecondition(GameErrorCode.busy, '대국자가 다른 일을 하고 있습니다');
        }
        // 받는 사람이 빠른 대국을 기다리고 있었으면 대기열에서 뺀다. 대기열 표시는 createGame이 지운다.
        if (targetState?.quickQueueJoinedAt != null) {
          quickQueue.deleteEntryInTransaction(transaction, toUid);
        }
        challenges.updateStatusInTransaction(
          transaction,
          challengeId,
          status: ChallengeStatus.accepted,
          gameId: gameId,
          now: now,
        );
        _resetLimitInTransaction(transaction, fromUid, toUid, now);
      },
    );
    return gameId;
  }

  /// 방 초대를 수락해 받는 사람을 방의 상대 자리에 앉힌다. 방이 닫혔거나 자리가 찼으면 신청을 `cancelled`로 바꾸고 그 사유로
  /// 거절한다. 방장이 초대한 사람이므로 공개 방의 급수 범위는 보지 않는다.
  Future<void> _acceptRoomInvite(
    String challengeId,
    Challenge challenge,
    String roomId, {
    required User user,
    required DateTime now,
  }) async {
    final fromUid = challenge.fromUid;
    final toUid = challenge.toUid;
    final rejection = await firestore.runTransaction((transaction) async {
      final (current, room, states) = await (
        challenges.getChallengeInTransaction(transaction, challengeId),
        rooms.getRoomInTransaction(transaction, roomId),
        playerStates.getPlayerStatesInTransaction(transaction, [fromUid, toUid]),
      ).wait;
      final senderState = states[fromUid];
      final targetState = states[toUid];
      if (current == null ||
          current.status != ChallengeStatus.pending ||
          senderState?.outgoingChallengeId != challengeId ||
          targetState?.incomingChallengeId != challengeId) {
        throw const CallableException.failedPrecondition(GameErrorCode.notFound, '응답할 신청이 없습니다');
      }
      if (targetState?.gameId != null || targetState?.roomId != null) {
        throw const CallableException.failedPrecondition(GameErrorCode.busy, '이미 방이나 대국에 있습니다');
      }
      GameErrorCode? rejection;
      if (room == null || room.status == RoomStatus.closed || room.hostUid != fromUid) {
        rejection = GameErrorCode.roomClosed;
      } else if (room.status != RoomStatus.waiting || room.guestUid != null) {
        rejection = GameErrorCode.roomFull;
      }
      if (rejection != null) {
        _closeInTransaction(
          transaction,
          challengeId,
          ChallengeStatus.cancelled,
          senderState,
          targetState,
          current,
          now,
        );
        return rejection;
      }
      rooms.updateGuestInTransaction(
        transaction,
        roomId,
        guestUid: toUid,
        guest: RoomPlayer(nickname: user.nickname, rankLevel: user.rankLevel),
        now: now,
      );
      if (targetState?.quickQueueJoinedAt != null) {
        quickQueue.deleteEntryInTransaction(transaction, toUid);
      }
      playerStates.setPlayerStateInTransaction(
        transaction,
        toUid,
        _copyState(
          targetState,
          outgoingChallengeId: null,
          incomingChallengeId: null,
          roomId: roomId,
          clearQuickQueue: true,
          now: now,
        ),
      );
      playerStates.setPlayerStateInTransaction(
        transaction,
        fromUid,
        _copyState(
          senderState,
          outgoingChallengeId: null,
          incomingChallengeId: senderState?.incomingChallengeId,
          now: now,
        ),
      );
      challenges.updateStatusInTransaction(transaction, challengeId, status: ChallengeStatus.accepted, now: now);
      _resetLimitInTransaction(transaction, fromUid, toUid, now);
      return null;
    });
    if (rejection != null) {
      throw CallableException.failedPrecondition(rejection, '초대한 방에 들어갈 수 없습니다');
    }
  }

  /// 응답을 기다리는 [challengeId]를 [status]로 끝내고 두 사람의 신청 표시를 지운다. 끝냈으면 true, 이미 끝났으면 false.
  /// `expired`는 응답 마감이 지났을 때만 끝낸다.
  Future<bool> _closeChallenge(String challengeId, ChallengeStatus status, {required DateTime now}) {
    return firestore.runTransaction((transaction) async {
      final challenge = await challenges.getChallengeInTransaction(transaction, challengeId);
      if (challenge == null || challenge.status != ChallengeStatus.pending) {
        return false;
      }
      if (status == ChallengeStatus.expired && now.isBefore(challenge.expiresAt)) {
        return false;
      }
      final states = await playerStates.getPlayerStatesInTransaction(transaction, [challenge.fromUid, challenge.toUid]);
      final limit = status == ChallengeStatus.cancelled
          ? null
          : await challengeLimits.getLimitInTransaction(transaction, challenge.fromUid, challenge.toUid);
      _closeInTransaction(
        transaction,
        challengeId,
        status,
        states[challenge.fromUid],
        states[challenge.toUid],
        challenge,
        now,
        limit: limit,
      );
      return true;
    });
  }

  /// 트랜잭션에서 읽은 신청을 [status]로 끝내는 쓰기. 거절과 응답 마감이면 [limit]에 연속 거절 횟수를 더한다.
  void _closeInTransaction(
    FirestoreTransaction transaction,
    String challengeId,
    ChallengeStatus status,
    PlayerState? senderState,
    PlayerState? targetState,
    Challenge challenge,
    DateTime now, {
    ChallengeLimit? limit,
  }) {
    challenges.updateStatusInTransaction(transaction, challengeId, status: status, now: now);
    if (senderState?.outgoingChallengeId == challengeId) {
      playerStates.setPlayerStateInTransaction(
        transaction,
        challenge.fromUid,
        _copyState(
          senderState,
          outgoingChallengeId: null,
          incomingChallengeId: senderState?.incomingChallengeId,
          now: now,
        ),
      );
    }
    if (targetState?.incomingChallengeId == challengeId) {
      playerStates.setPlayerStateInTransaction(
        transaction,
        challenge.toUid,
        _copyState(
          targetState,
          outgoingChallengeId: targetState?.outgoingChallengeId,
          incomingChallengeId: null,
          now: now,
        ),
      );
    }
    if (status == ChallengeStatus.declined || status == ChallengeStatus.expired) {
      final failCount = (limit?.failCount ?? 0) + 1;
      final next = failCount >= challengeFailLimit
          ? ChallengeLimit(failCount: 0, blockedUntil: now.add(blockTime), updatedAt: now)
          : ChallengeLimit(failCount: failCount, blockedUntil: limit?.blockedUntil, updatedAt: now);
      challengeLimits.setLimitInTransaction(transaction, challenge.fromUid, challenge.toUid, next);
    }
  }

  void _resetLimitInTransaction(FirestoreTransaction transaction, String fromUid, String toUid, DateTime now) {
    challengeLimits.setLimitInTransaction(
      transaction,
      fromUid,
      toUid,
      ChallengeLimit(failCount: 0, blockedUntil: null, updatedAt: now),
    );
  }

  /// 방 초대를 보낼 수 있는지. [uid]가 [roomId]의 방장이고 방이 상대를 기다리며 다른 신청이 없어야 한다. 방장이 내보낸 사람은
  /// 방이 닫힐 때까지 다시 들어올 수 없으므로 초대하지 못한다(`targetUnavailable`).
  void _checkCanInvite(
    Room? room,
    String roomId, {
    required String uid,
    required PlayerState? sender,
    required String toUid,
  }) {
    if (room == null) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '방이 없습니다');
    }
    if (room.status == RoomStatus.closed) {
      throw const CallableException.failedPrecondition(GameErrorCode.roomClosed, '닫힌 방입니다');
    }
    if (room.hostUid != uid) {
      throw const CallableException.failedPrecondition(GameErrorCode.notHost, '방장만 초대할 수 있습니다');
    }
    if (room.status != RoomStatus.waiting || room.guestUid != null) {
      throw const CallableException.failedPrecondition(GameErrorCode.roomFull, '방에 자리가 없습니다');
    }
    if (sender?.roomId != roomId ||
        sender?.gameId != null ||
        sender?.quickQueueJoinedAt != null ||
        sender?.outgoingChallengeId != null ||
        sender?.incomingChallengeId != null) {
      throw const CallableException.failedPrecondition(GameErrorCode.busy, '방 밖의 일을 하고 있습니다');
    }
    if (room.kickedUids.contains(toUid)) {
      throw const CallableException.failedPrecondition(GameErrorCode.targetUnavailable, '내보낸 사람은 초대할 수 없습니다');
    }
  }

  /// 신청을 받을 수 있는 상태. 방, 대국, 다른 신청이 없어야 한다. 빠른 대국 대기열에 있는 것은 괜찮다.
  static bool _isAvailableTarget(PlayerState? state) {
    return state == null ||
        (state.gameId == null &&
            state.roomId == null &&
            state.outgoingChallengeId == null &&
            state.incomingChallengeId == null);
  }

  /// 보낸 사람의 진영. 접장기면 떼는 쪽이 한이다(`docs/game/handicap.md`).
  Side _getSenderSide(Challenge challenge) {
    final handicap = challenge.handicap;
    if (handicap != null) {
      return handicap.remover == HandicapRemover.creator ? Side.han : Side.cho;
    }
    return switch (challenge.senderSide) {
      SideChoice.cho => Side.cho,
      SideChoice.han => Side.han,
      SideChoice.random || null => _random.nextBool() ? Side.cho : Side.han,
    };
  }

  /// [state]에서 신청 표시를 바꾼 상태. [roomId]를 주면 방에 넣고, [clearQuickQueue]면 대기열 표시를 지운다. 문서가 없었으면
  /// 나머지는 비운다.
  static PlayerState _copyState(
    PlayerState? state, {
    required String? outgoingChallengeId,
    required String? incomingChallengeId,
    String? roomId,
    bool clearQuickQueue = false,
    required DateTime now,
  }) {
    return PlayerState(
      roomId: roomId ?? state?.roomId,
      gameId: state?.gameId,
      lastGameId: state?.lastGameId,
      outgoingChallengeId: outgoingChallengeId,
      incomingChallengeId: incomingChallengeId,
      setupDraft: state?.setupDraft,
      lastRankChange: state?.lastRankChange,
      quickQueueJoinedAt: clearQuickQueue ? null : state?.quickQueueJoinedAt,
      updatedAt: now,
    );
  }
}
