import 'dart:math';

import 'package:janggi_core/janggi_core.dart';

import '../config.dart';
import '../firebase/firestore_client.dart';
import '../http/callable.dart';
import '../logging.dart';
import '../models/active_game.dart';
import '../models/game_enums.dart';
import '../models/player_state.dart';
import '../models/room.dart';
import '../models/user.dart';
import '../repositories/active_games_repository.dart';
import '../repositories/configs_repository.dart';
import '../repositories/connections_repository.dart';
import '../repositories/player_states_repository.dart';
import '../repositories/rooms_repository.dart';
import '../repositories/users_repository.dart';
import '../tasks/task_scheduler.dart';
import 'game_rules.dart';
import 'game_service.dart';

/// 방을 만들 때 방장이 정하는 조건(`docs/game/matching.md`의 방 만들기).
class RoomOptions {
  final SideChoice hostSide;
  final RoomHandicap? handicap;
  final bool listed;

  /// 공개 방에서만 준다. null이면 모든 급수.
  final RankRange? rankRange;

  const RoomOptions({required this.hostSide, required this.handicap, required this.listed, required this.rankRange});
}

/// 방 만들기, 들어가기, 나가기, 내보내기, 대국 시작과 방 유지(`docs/server.md`의 방).
///
/// 방은 Firestore `rooms`, 사용자가 방에 있다는 표시는 `player_states.roomId`다. 둘은 같은 트랜잭션에서 함께 바꾼다.
/// 방 대국은 [GameService.createGame]이 두 사람을 묶는 트랜잭션에서 방을 `playing`으로 바꾸고, 대국이 끝나면
/// [GameService.finalizeGame]이 `waiting`으로 돌린다. 두 사람의 `roomId`는 대국 중에도 남아 결과 화면을 나가면 방 대기실로 돌아온다.
class RoomService {
  /// Firestore 트랜잭션을 시작할 때만 쓴다. 문서 읽기·쓰기는 repository가 한다.
  final FirestoreClient firestore;
  final GameService gameService;
  final RoomsRepository rooms;
  final PlayerStatesRepository playerStates;
  final ActiveGamesRepository activeGames;
  final UsersRepository users;
  final ConnectionsRepository connections;
  final ConfigsRepository configs;
  final TaskScheduler taskScheduler;
  final GameLogger logger;
  final NewGameSettings settings;

  /// `checkRoom` 간격. 운영은 [roomCheckInterval]이고 통합 테스트는 짧게 줄인다.
  final Duration checkInterval;

  /// 방장이나 상대의 연결이 이만큼 없으면 방을 닫거나 자리를 비운다. 운영은 [roomAbsentSeconds]다.
  final Duration absentLimit;
  final Random _random;

  RoomService({
    required this.firestore,
    required this.gameService,
    required this.rooms,
    required this.playerStates,
    required this.activeGames,
    required this.users,
    required this.connections,
    required this.configs,
    required this.taskScheduler,
    required this.logger,
    required this.settings,
    this.checkInterval = roomCheckInterval,
    this.absentLimit = const Duration(seconds: roomAbsentSeconds),
    Random? random,
  }) : _random = random ?? Random();

  /// [uid]가 [options]로 방을 만들고 방 ID를 돌려준다. 이용 정지 중이면 `sanctioned`, 이미 대기열·방·대국·신청 중 하나에
  /// 있으면 `busy`로 거절한다. 방이 열려 있는 동안 `checkRoom`을 예약한다.
  Future<String> createRoom(String uid, User user, RoomOptions options, {required DateTime now}) async {
    await gameService.checkNotSanctioned(uid, now);
    await gameService.settlePreviousGames([uid], now);
    final roomId = rooms.createRoomId();
    final room = Room(
      hostUid: uid,
      host: RoomPlayer(nickname: user.nickname, rankLevel: user.rankLevel),
      guestUid: null,
      guest: null,
      status: RoomStatus.waiting,
      listed: options.listed,
      hostSide: options.hostSide,
      handicap: options.handicap,
      rankRange: options.rankRange,
      gameId: null,
      kickedUids: const [],
      hostAbsentSince: null,
      guestAbsentSince: null,
      createdAt: now,
      updatedAt: now,
    );
    await firestore.runTransaction((transaction) async {
      final states = await playerStates.getPlayerStatesInTransaction(transaction, [uid]);
      final state = states[uid];
      if (GameService.isBusy(state)) {
        throw const CallableException.failedPrecondition(GameErrorCode.busy, '이미 대기열, 방, 대국, 신청 중 하나에 있습니다');
      }
      rooms.createRoomInTransaction(transaction, roomId, room);
      playerStates.setPlayerStateInTransaction(transaction, uid, _withRoomId(state, roomId, now));
    });
    await _scheduleCheck(roomId, room, now);
    logger.info('createRoom 성공', {
      'roomId': roomId,
      'uid': uid,
      'listed': options.listed,
      'handicapped': options.handicap != null,
    });
    return roomId;
  }

  /// [uid]가 [roomId]의 빈자리에 앉는다. 링크와 방 목록이 모두 이것을 쓴다. 이미 이 방에 있으면 그대로 성공한다.
  ///
  /// 방이 없으면 `notFound`, 닫혔으면 `roomClosed`, 내보내진 사람이면 `kicked`, 자리가 찼으면 `roomFull`(대국 중 포함),
  /// 급수 범위 밖이면 `rankOutOfRange`, 다른 대기열·방·대국·신청에 있으면 `busy`, 이용 정지 중이면 `sanctioned`다.
  Future<void> joinRoom(String roomId, {required String uid, required User user, required DateTime now}) async {
    await gameService.checkNotSanctioned(uid, now);
    await gameService.settlePreviousGames([uid], now);
    final joined = await firestore.runTransaction((transaction) async {
      final (room, states) = await (
        rooms.getRoomInTransaction(transaction, roomId),
        playerStates.getPlayerStatesInTransaction(transaction, [uid]),
      ).wait;
      if (room == null) {
        throw const CallableException.failedPrecondition(GameErrorCode.notFound, '방이 없습니다');
      }
      if (room.status == RoomStatus.closed) {
        throw const CallableException.failedPrecondition(GameErrorCode.roomClosed, '닫힌 방입니다');
      }
      if (room.hostUid == uid || room.guestUid == uid) {
        return false;
      }
      if (room.kickedUids.contains(uid)) {
        throw const CallableException.failedPrecondition(GameErrorCode.kicked, '이 방에서 내보내졌습니다');
      }
      if (room.guestUid != null) {
        throw const CallableException.failedPrecondition(GameErrorCode.roomFull, '방에 자리가 없습니다');
      }
      final rankRange = room.rankRange;
      if (rankRange != null && (user.rankLevel < rankRange.min || user.rankLevel > rankRange.max)) {
        throw const CallableException.failedPrecondition(GameErrorCode.rankOutOfRange, '방의 급수 범위 밖입니다');
      }
      final state = states[uid];
      if (GameService.isBusy(state)) {
        throw const CallableException.failedPrecondition(GameErrorCode.busy, '이미 대기열, 방, 대국, 신청 중 하나에 있습니다');
      }
      rooms.updateGuestInTransaction(
        transaction,
        roomId,
        guestUid: uid,
        guest: RoomPlayer(nickname: user.nickname, rankLevel: user.rankLevel),
        now: now,
      );
      playerStates.setPlayerStateInTransaction(transaction, uid, _withRoomId(state, roomId, now));
      return true;
    });
    logger.info('joinRoom 성공', {'roomId': roomId, 'uid': uid, 'joined': joined});
  }

  /// [uid]가 [roomId]에서 나간다. 방장이면 방을 닫고 상대도 내보낸다. 이미 나갔거나 방이 없으면 그대로 성공한다.
  /// 방의 대국이 진행 중이면 `busy`로 거절한다.
  Future<void> leaveRoom(String roomId, {required String uid, required DateTime now}) async {
    // 끝났어야 하는 방 대국을 먼저 정리해 방을 `waiting`으로 돌린다.
    await gameService.settlePreviousGames([uid], now);
    final result = await firestore.runTransaction((transaction) async {
      final room = await rooms.getRoomInTransaction(transaction, roomId);
      final memberUids = [?room?.hostUid, ?room?.guestUid];
      final states = await playerStates.getPlayerStatesInTransaction(transaction, {uid, ...memberUids}.toList());
      final inRoom = room != null && room.status != RoomStatus.closed && memberUids.contains(uid);
      if (!inRoom) {
        _clearRoomId(transaction, uid, states[uid], roomId, now);
        return 'notInRoom';
      }
      if (room.status == RoomStatus.playing) {
        throw const CallableException.failedPrecondition(GameErrorCode.busy, '대국 중에는 방을 나갈 수 없습니다');
      }
      if (room.hostUid == uid) {
        rooms.updateStatusInTransaction(transaction, roomId, status: RoomStatus.closed, now: now);
        for (final memberUid in memberUids) {
          _clearRoomId(transaction, memberUid, states[memberUid], roomId, now);
        }
        return 'closed';
      }
      rooms.updateGuestInTransaction(transaction, roomId, guestUid: null, guest: null, now: now);
      _clearRoomId(transaction, uid, states[uid], roomId, now);
      return 'left';
    });
    logger.info('leaveRoom 성공', {'roomId': roomId, 'uid': uid, 'result': result});
  }

  /// 방장 [uid]가 상대를 내보낸다. 내보낸 사람은 방이 닫힐 때까지 다시 들어오지 못한다. 상대가 없으면 그대로 성공한다.
  /// 방장이 아니면 `notHost`, 대국 중이면 `busy`다.
  Future<void> kickGuest(String roomId, {required String uid, required DateTime now}) async {
    final room = await rooms.getRoom(roomId);
    final guestUid = room?.guestUid;
    if (guestUid != null) {
      // 끝났어야 하는 방 대국을 먼저 정리해 방을 `waiting`으로 돌린다.
      await gameService.settlePreviousGames([uid, guestUid], now);
    }
    final kickedUid = await firestore.runTransaction((transaction) async {
      final room = _requireOpenRoom(await rooms.getRoomInTransaction(transaction, roomId));
      if (room.hostUid != uid) {
        throw const CallableException.failedPrecondition(GameErrorCode.notHost, '방장만 내보낼 수 있습니다');
      }
      final guestUid = room.guestUid;
      if (guestUid == null) {
        return null;
      }
      if (room.status == RoomStatus.playing) {
        throw const CallableException.failedPrecondition(GameErrorCode.busy, '대국 중에는 내보낼 수 없습니다');
      }
      final states = await playerStates.getPlayerStatesInTransaction(transaction, [guestUid]);
      rooms.updateGuestInTransaction(
        transaction,
        roomId,
        guestUid: null,
        guest: null,
        kickedUids: [...room.kickedUids, guestUid],
        now: now,
      );
      _clearRoomId(transaction, guestUid, states[guestUid], roomId, now);
      return guestUid;
    });
    logger.info('kickGuest 성공', {'roomId': roomId, 'uid': uid, 'kickedUid': kickedUid});
  }

  /// 방장 [uid]가 대국을 시작하고 대국 ID를 돌려준다. 이미 대국 중이면 그 대국 ID를 돌려준다.
  ///
  /// 진영은 접장기면 떼는 쪽이 한이고, 아니면 방장이 고른 진영이다(무작위면 판마다 정한다). 방장이 아니면 `notHost`,
  /// 상대가 없으면 `notFound`, 닫힌 방이면 `roomClosed`다.
  Future<String> startRoomGame(String roomId, {required String uid, required DateTime now}) async {
    final room = _requireOpenRoom(await rooms.getRoom(roomId));
    if (room.hostUid != uid) {
      throw const CallableException.failedPrecondition(GameErrorCode.notHost, '방장만 대국을 시작할 수 있습니다');
    }
    final currentGameId = room.gameId;
    if (room.status == RoomStatus.playing && currentGameId != null) {
      return currentGameId;
    }
    final guestUid = room.guestUid;
    if (guestUid == null) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '상대가 없습니다');
    }
    final (profiles, appConfig) = await (users.getUsers([uid, guestUid]), configs.getAppConfig()).wait;
    final hostProfile = profiles[uid];
    final guestProfile = profiles[guestUid];
    if (hostProfile == null || guestProfile == null) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '대국자의 프로필이 없습니다');
    }
    final host = GamePlayer(uid: uid, nickname: hostProfile.nickname, rankLevel: hostProfile.rankLevel);
    final guest = GamePlayer(uid: guestUid, nickname: guestProfile.nickname, rankLevel: guestProfile.rankLevel);
    final hostSide = _getHostSide(room);
    final game = createActiveGame(
      mode: GameMode.room,
      rated: false,
      listed: room.listed,
      players: hostSide == Side.cho ? GamePlayers(cho: host, han: guest) : GamePlayers(cho: guest, han: host),
      timeControl: settings.timeControl,
      disconnectLimitMs: settings.getDisconnectLimitMs(appConfig),
      now: now.millisecondsSinceEpoch,
      roomId: roomId,
      handicap: room.handicap?.pieces,
    );
    final gameId = activeGames.createGameId();
    await gameService.createGame(
      game,
      now: now,
      gameId: gameId,
      check: bindRoomGame(roomId, gameId: gameId, uids: [uid, guestUid], now: now),
    );
    logger.info('startRoomGame 성공', {'roomId': roomId, 'gameId': gameId, 'hostSide': hostSide.name});
    return gameId;
  }

  /// [roomId]의 대국 [gameId]에 [uids] 두 사람을 묶는 확인. [GameService.createGame]의 트랜잭션에서 방이 아직 기다리는 중이고
  /// 두 사람이 그 방의 방장과 상대이며 다른 대국·대기열·신청이 없는지 확인한 뒤 방을 `playing`으로 바꾼다. 아니면 `busy`다.
  /// 방 대국의 다시 두기도 이것을 쓴다.
  GameBindingCheck bindRoomGame(
    String roomId, {
    required String gameId,
    required List<String> uids,
    required DateTime now,
  }) {
    return (transaction, states) async {
      final room = await rooms.getRoomInTransaction(transaction, roomId);
      final members = {room?.hostUid, room?.guestUid};
      if (room == null || room.status != RoomStatus.waiting || !uids.every(members.contains) || room.guestUid == null) {
        throw const CallableException.failedPrecondition(GameErrorCode.busy, '방이 대국을 시작할 수 있는 상태가 아닙니다');
      }
      for (final uid in uids) {
        final state = states[uid];
        if (state == null ||
            state.roomId != roomId ||
            state.gameId != null ||
            state.quickQueueJoinedAt != null ||
            state.outgoingChallengeId != null ||
            state.incomingChallengeId != null) {
          throw const CallableException.failedPrecondition(GameErrorCode.busy, '대국자가 방 밖의 일을 하고 있습니다');
        }
      }
      rooms.updateStatusInTransaction(transaction, roomId, status: RoomStatus.playing, gameId: gameId, now: now);
    };
  }

  /// `checkRoom` 예약 작업. 방장의 연결이 [absentLimit] 넘게 없으면 방을 닫고, 상대의 연결이 그만큼 없으면 자리를 비운다.
  ///
  /// 연결은 `online`인 연결이 하나라도 있으면 있는 것으로 본다. 링크를 공유하려고 다른 앱에 간 방장을 내보내지 않도록
  /// `foreground`는 보지 않는다. 대국 중에는 대국의 접속 끊김 판정에 맡기고 확인하지 않는다. 방이 닫히기 전까지 다시 예약한다.
  Future<void> checkRoom(String roomId, {required DateTime now}) async {
    final room = await rooms.getRoom(roomId);
    if (room == null || room.status == RoomStatus.closed) {
      logger.debug('checkRoom 끝: 닫힌 방입니다', {'roomId': roomId});
      return;
    }
    if (room.status == RoomStatus.playing) {
      await _scheduleCheck(roomId, room, now);
      return;
    }
    final guestUid = room.guestUid;
    final (hostOnline, guestOnline) = await (
      _isOnline(room.hostUid),
      guestUid == null ? Future.value(false) : _isOnline(guestUid),
    ).wait;
    final result = await firestore.runTransaction((transaction) async {
      final current = await rooms.getRoomInTransaction(transaction, roomId);
      if (current == null || current.status != RoomStatus.waiting || current.guestUid != guestUid) {
        return 'changed';
      }
      final hostAbsentSince = hostOnline ? null : (current.hostAbsentSince ?? now);
      final guestAbsentSince = guestUid == null || guestOnline ? null : (current.guestAbsentSince ?? now);
      final memberUids = [current.hostUid, ?guestUid];
      if (hostAbsentSince != null && !now.isBefore(hostAbsentSince.add(absentLimit))) {
        final states = await playerStates.getPlayerStatesInTransaction(transaction, memberUids);
        rooms.updateStatusInTransaction(transaction, roomId, status: RoomStatus.closed, now: now);
        for (final memberUid in memberUids) {
          _clearRoomId(transaction, memberUid, states[memberUid], roomId, now);
        }
        return 'closed';
      }
      if (guestUid != null && guestAbsentSince != null && !now.isBefore(guestAbsentSince.add(absentLimit))) {
        final states = await playerStates.getPlayerStatesInTransaction(transaction, [guestUid]);
        rooms.updateGuestInTransaction(transaction, roomId, guestUid: null, guest: null, now: now);
        _clearRoomId(transaction, guestUid, states[guestUid], roomId, now);
        return 'guestRemoved';
      }
      if (hostAbsentSince != current.hostAbsentSince || guestAbsentSince != current.guestAbsentSince) {
        rooms.updateAbsenceInTransaction(
          transaction,
          roomId,
          hostAbsentSince: hostAbsentSince,
          guestAbsentSince: guestAbsentSince,
          now: now,
        );
      }
      return 'checked';
    });
    if (result != 'closed') {
      await _scheduleCheck(roomId, room, now);
    }
    logger.info('checkRoom 완료', {
      'roomId': roomId,
      'result': result,
      'hostOnline': hostOnline,
      'guestOnline': guestOnline,
    });
  }

  Future<bool> _isOnline(String uid) async {
    final userConnections = await connections.getConnections(uid);
    return userConnections.any((connection) => connection.online);
  }

  /// 방을 만든 시각부터 [checkInterval]마다의 다음 시각에 `checkRoom`을 예약한다. 같은 시각은 한 번만 예약한다.
  Future<void> _scheduleCheck(String roomId, Room room, DateTime now) async {
    final intervalMs = checkInterval.inMilliseconds;
    final tick = now.difference(room.createdAt).inMilliseconds ~/ intervalMs + 1;
    final runAt = room.createdAt.add(checkInterval * tick);
    await taskScheduler.schedule(
      TaskName.checkRoom,
      {'roomId': roomId, 'eventAt': runAt.millisecondsSinceEpoch},
      runAt: runAt,
      taskId: 'room-$roomId-$tick',
    );
  }

  /// 이번 판의 방장 진영. 접장기면 떼는 쪽이 한이다(`docs/game/handicap.md`).
  Side _getHostSide(Room room) {
    final handicap = room.handicap;
    if (handicap != null) {
      return handicap.remover == HandicapRemover.creator ? Side.han : Side.cho;
    }
    return switch (room.hostSide) {
      SideChoice.cho => Side.cho,
      SideChoice.han => Side.han,
      SideChoice.random => _random.nextBool() ? Side.cho : Side.han,
    };
  }

  /// 방이 있고 닫히지 않았는지 확인한다. 없으면 `notFound`, 닫혔으면 `roomClosed`.
  static Room _requireOpenRoom(Room? room) {
    if (room == null) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '방이 없습니다');
    }
    if (room.status == RoomStatus.closed) {
      throw const CallableException.failedPrecondition(GameErrorCode.roomClosed, '닫힌 방입니다');
    }
    return room;
  }

  /// [uid]의 상태가 [roomId]에 있으면 방에서 뺀다. 다른 방에 있거나 문서가 없으면 그대로 둔다.
  void _clearRoomId(FirestoreTransaction transaction, String uid, PlayerState? state, String roomId, DateTime now) {
    if (state?.roomId != roomId) {
      return;
    }
    playerStates.setPlayerStateInTransaction(transaction, uid, _withRoomId(state, null, now));
  }

  /// [state]에서 방 표시만 바꾼 상태. 문서가 없었으면 나머지는 비운다.
  static PlayerState _withRoomId(PlayerState? state, String? roomId, DateTime now) {
    return PlayerState(
      roomId: roomId,
      gameId: state?.gameId,
      lastGameId: state?.lastGameId,
      outgoingChallengeId: state?.outgoingChallengeId,
      incomingChallengeId: state?.incomingChallengeId,
      setupDraft: state?.setupDraft,
      lastRankChange: state?.lastRankChange,
      quickQueueJoinedAt: state?.quickQueueJoinedAt,
      updatedAt: now,
    );
  }
}
