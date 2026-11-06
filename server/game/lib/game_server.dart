import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'auth/id_token_verifier.dart';
import 'auth/public_keys.dart';
import 'auth/task_request_verifier.dart';
import 'clock.dart';
import 'config.dart';
import 'endpoints/challenge_endpoints.dart';
import 'endpoints/check_game.dart';
import 'endpoints/check_room.dart';
import 'endpoints/create_room.dart';
import 'endpoints/dev_create_game.dart';
import 'endpoints/dev_ping.dart';
import 'endpoints/dev_ping_task.dart';
import 'endpoints/enter_lobby.dart';
import 'endpoints/expire_challenge.dart';
import 'endpoints/game_tasks.dart';
import 'endpoints/join_quick_queue.dart';
import 'endpoints/leave_quick_queue.dart';
import 'endpoints/leave_result.dart';
import 'endpoints/play_move.dart';
import 'endpoints/request_rematch.dart';
import 'endpoints/resign.dart';
import 'endpoints/retry_quick_match.dart';
import 'endpoints/room_endpoints.dart';
import 'endpoints/send_challenge.dart';
import 'endpoints/set_formation.dart';
import 'firebase/access_token.dart';
import 'firebase/firestore_client.dart';
import 'firebase/rtdb_client.dart';
import 'http/callable.dart';
import 'http/callable_handler.dart';
import 'http/middleware.dart';
import 'http/task_handler.dart';
import 'logging.dart';
import 'models/active_game.dart';
import 'repositories/game_repositories.dart';
import 'server_environment.dart';
import 'services/challenge_service.dart';
import 'services/game_service.dart';
import 'services/lobby_service.dart';
import 'services/quick_match_service.dart';
import 'services/rematch_service.dart';
import 'services/room_service.dart';
import 'tasks/cloud_tasks_scheduler.dart';
import 'tasks/local_task_scheduler.dart';
import 'tasks/task_scheduler.dart';

/// 대국 서버의 의존성 조립과 HTTP 서버. 운영과 에뮬레이터의 차이는 [GameServer.create]에만 둔다.
class GameServer {
  final ServerEnvironment environment;
  final GameLogger logger;
  final Clock clock;

  /// 인증 헤더 없는 클라이언트. 공개 키와 메타데이터 서버를 부를 때 쓰고, 다른 클라이언트가 감싼다.
  final http.Client httpClient;
  final FirestoreClient firestore;
  final RtdbClient rtdb;
  final GameRepositories repositories;
  final GameService gameService;
  final TaskScheduler taskScheduler;
  final FirebaseIdTokenVerifier idTokenVerifier;
  final TaskRequestVerifier taskVerifier;
  final List<CallableEndpoint> callables;
  final List<TaskEndpoint> tasks;

  HttpServer? _httpServer;

  GameServer({
    required this.environment,
    required this.logger,
    required this.clock,
    required this.httpClient,
    required this.firestore,
    required this.rtdb,
    required this.repositories,
    required this.gameService,
    required this.taskScheduler,
    required this.idTokenVerifier,
    required this.taskVerifier,
    required this.callables,
    required this.tasks,
  });

  /// [environment]에 맞게 조립한다. 에뮬레이터에서는 개발용 API(`devPing`, `devCreateGame`)를 함께 연다.
  ///
  /// [onDevPingTask]는 테스트가 `devPing` 예약 작업이 돌았는지 확인할 때 쓴다.
  /// [testTimeControl], [testDisconnectLimit], [testQuickMatchStepInterval]은 에뮬레이터에서 만드는 모든
  /// 대국(개발용, 빠른 대국, 방, 다시 두기)의 시간과 매칭 범위를 넓히는 간격이다. [testRoomCheckInterval], [testRoomAbsentLimit]은
  /// 방 연결 확인 간격과 방을 닫거나 자리를 비우기까지의 시간이다. [testChallengeResponse], [testChallengeBlock]은 신청 응답
  /// 시간과 연속 거절 제한 시간이다. 통합 테스트가 짧게 줄일 때 쓰고 운영에서는 무시한다.
  factory GameServer.create({
    required ServerEnvironment environment,
    required GameLogger logger,
    http.Client? httpClient,
    Clock clock = utcNow,
    void Function(DevPingTaskParams params)? onDevPingTask,
    TimeControl? testTimeControl,
    Duration? testMatchIntro,
    Duration? testDisconnectLimit,
    Duration? testQuickMatchStepInterval,
    Duration? testRoomCheckInterval,
    Duration? testRoomAbsentLimit,
    Duration? testChallengeResponse,
    Duration? testChallengeBlock,
  }) {
    final baseClient = httpClient ?? http.Client();
    final production = environment.mode == ServerMode.production;
    final AccessTokenProvider tokenProvider = production
        ? MetadataServerAccessTokenProvider(httpClient: baseClient, clock: clock)
        : const EmulatorAccessTokenProvider();
    final authorizedClient = AuthorizedClient(inner: baseClient, tokenProvider: tokenProvider);
    final firestore = FirestoreClient(
      httpClient: authorizedClient,
      baseUri: environment.firestoreBaseUri,
      projectId: environment.projectId,
    );
    final rtdb = RtdbClient(httpClient: authorizedClient, baseUri: environment.rtdbBaseUri);
    final repositories = GameRepositories.createDefault(firestore: firestore, rtdb: rtdb, clock: clock);

    final TaskScheduler taskScheduler;
    final TaskRequestVerifier taskVerifier;
    final FirebaseIdTokenVerifier idTokenVerifier;
    final cloudTasks = environment.cloudTasks;
    if (production) {
      if (cloudTasks == null) {
        throw StateError('운영에는 Cloud Tasks 설정이 필요합니다');
      }
      idTokenVerifier = FirebaseIdTokenVerifier.production(
        projectId: environment.projectId,
        keySource: GoogleJwkKeySource(
          url: GoogleJwkKeySource.firebaseIdTokenKeysUrl,
          httpClient: baseClient,
          clock: clock,
        ),
        clock: clock,
      );
      taskScheduler = CloudTasksScheduler(
        httpClient: authorizedClient,
        projectId: environment.projectId,
        environment: cloudTasks,
        logger: logger,
      );
      taskVerifier = CloudTasksOidcVerifier(
        audience: cloudTasks.serverUrl.toString(),
        serviceAccountEmail: cloudTasks.serviceAccountEmail,
        keySource: GoogleJwkKeySource(url: GoogleJwkKeySource.googleOidcKeysUrl, httpClient: baseClient, clock: clock),
        clock: clock,
      );
    } else {
      idTokenVerifier = FirebaseIdTokenVerifier.emulator(projectId: environment.projectId, clock: clock);
      final localVerifier = LocalTaskVerifier.random();
      taskScheduler = LocalTaskScheduler(
        httpClient: baseClient,
        secret: localVerifier.secret,
        logger: logger,
        clock: clock,
      );
      taskVerifier = localVerifier;
    }

    final gameService = GameService(
      firestore: firestore,
      activeGames: repositories.activeGames,
      playerStates: repositories.playerStates,
      archivedGames: repositories.archivedGames,
      connections: repositories.connections,
      ratings: repositories.ratings,
      users: repositories.users,
      usersPrivate: repositories.usersPrivate,
      rooms: repositories.rooms,
      onlineUsers: repositories.onlineUsers,
      spectateList: repositories.spectateList,
      spectators: repositories.spectators,
      configs: repositories.configs,
      coinWallets: repositories.coinWallets,
      coinTransactions: repositories.coinTransactions,
      taskScheduler: taskScheduler,
      logger: logger,
    );
    final newGameSettings = production
        ? NewGameSettings(timeControl: defaultTimeControl, disconnectLimit: null)
        : NewGameSettings(timeControl: testTimeControl ?? defaultTimeControl, disconnectLimit: testDisconnectLimit);
    final quickMatchService = QuickMatchService(
      firestore: firestore,
      gameService: gameService,
      quickQueue: repositories.quickQueue,
      playerStates: repositories.playerStates,
      ratings: repositories.ratings,
      users: repositories.users,
      connections: repositories.connections,
      configs: repositories.configs,
      taskScheduler: taskScheduler,
      logger: logger,
      settings: newGameSettings,
      stepInterval: (production ? null : testQuickMatchStepInterval) ?? quickMatchStepInterval,
    );
    final roomService = RoomService(
      firestore: firestore,
      gameService: gameService,
      rooms: repositories.rooms,
      playerStates: repositories.playerStates,
      activeGames: repositories.activeGames,
      users: repositories.users,
      connections: repositories.connections,
      configs: repositories.configs,
      taskScheduler: taskScheduler,
      logger: logger,
      settings: newGameSettings,
      checkInterval: (production ? null : testRoomCheckInterval) ?? roomCheckInterval,
      absentLimit: (production ? null : testRoomAbsentLimit) ?? const Duration(seconds: roomAbsentSeconds),
    );
    final rematchService = RematchService(
      gameService: gameService,
      roomService: roomService,
      activeGames: repositories.activeGames,
      users: repositories.users,
      connections: repositories.connections,
      configs: repositories.configs,
      logger: logger,
      settings: newGameSettings,
    );
    final challengeService = ChallengeService(
      firestore: firestore,
      gameService: gameService,
      challenges: repositories.challenges,
      challengeLimits: repositories.challengeLimits,
      userBlocks: repositories.userBlocks,
      onlineUsers: repositories.onlineUsers,
      playerStates: repositories.playerStates,
      rooms: repositories.rooms,
      quickQueue: repositories.quickQueue,
      activeGames: repositories.activeGames,
      users: repositories.users,
      usersPrivate: repositories.usersPrivate,
      configs: repositories.configs,
      taskScheduler: taskScheduler,
      logger: logger,
      settings: newGameSettings,
      responseTime: (production ? null : testChallengeResponse) ?? const Duration(seconds: challengeResponseSeconds),
      blockTime: (production ? null : testChallengeBlock) ?? const Duration(minutes: challengeBlockMinutes),
    );
    final lobbyService = LobbyService(
      onlineUsers: repositories.onlineUsers,
      playerStates: repositories.playerStates,
      usersPrivate: repositories.usersPrivate,
      logger: logger,
    );

    return GameServer(
      environment: environment,
      logger: logger,
      clock: clock,
      httpClient: baseClient,
      firestore: firestore,
      rtdb: rtdb,
      repositories: repositories,
      gameService: gameService,
      taskScheduler: taskScheduler,
      idTokenVerifier: idTokenVerifier,
      taskVerifier: taskVerifier,
      callables: [
        SetFormationEndpoint(gameService: gameService, logger: logger),
        PlayMoveEndpoint(gameService: gameService, logger: logger),
        ResignEndpoint(gameService: gameService, logger: logger),
        CheckGameEndpoint(gameService: gameService, logger: logger),
        JoinQuickQueueEndpoint(quickMatchService: quickMatchService),
        LeaveQuickQueueEndpoint(quickMatchService: quickMatchService),
        RequestRematchEndpoint(rematchService: rematchService),
        LeaveResultEndpoint(rematchService: rematchService),
        CreateRoomEndpoint(roomService: roomService),
        JoinRoomEndpoint(roomService: roomService),
        LeaveRoomEndpoint(roomService: roomService),
        KickGuestEndpoint(roomService: roomService),
        StartRoomGameEndpoint(roomService: roomService),
        EnterLobbyEndpoint(lobbyService: lobbyService),
        SendChallengeEndpoint(challengeService: challengeService),
        RespondChallengeEndpoint(challengeService: challengeService),
        CancelChallengeEndpoint(challengeService: challengeService),
        if (!production) ...[
          DevPingEndpoint(taskScheduler: taskScheduler, logger: logger),
          DevCreateGameEndpoint(
            gameService: gameService,
            nicknames: repositories.nicknames,
            users: repositories.users,
            configs: repositories.configs,
            logger: logger,
            settings: newGameSettings,
          ),
        ],
      ],
      tasks: [
        EvaluateGameTaskEndpoint(gameService: gameService, logger: logger),
        FinalizeGameTaskEndpoint(gameService: gameService),
        CleanupGameTaskEndpoint(gameService: gameService),
        RetryQuickMatchTaskEndpoint(quickMatchService: quickMatchService),
        CheckRoomTaskEndpoint(roomService: roomService),
        ExpireChallengeTaskEndpoint(challengeService: challengeService),
        if (!production) DevPingTaskEndpoint(logger: logger, onRun: onDevPingTask),
      ],
    );
  }

  /// 모든 경로를 담은 shelf 핸들러.
  Handler createHandler() {
    final router = Router(notFoundHandler: (_) => Response.notFound(null));
    // 배포 뒤 서버가 떴는지 확인하는 경로. Cloud Run은 `z`로 끝나는 `/healthz`를 가로채므로 쓰지 않는다.
    router.get('/health', (Request _) => Response.ok('ok'));
    for (final endpoint in callables) {
      router.all(
        '/${endpoint.name}',
        createCallableHandler(
          endpoint: endpoint,
          idTokenVerifier: idTokenVerifier,
          usersRepository: repositories.users,
          logger: logger,
          clock: clock,
        ),
      );
    }
    for (final endpoint in tasks) {
      router.post(
        endpoint.name.path,
        createTaskHandler(endpoint: endpoint, verifier: taskVerifier, logger: logger, clock: clock),
      );
    }
    return const Pipeline()
        .addMiddleware(traceMiddleware(environment.projectId))
        .addMiddleware(corsMiddleware())
        .addHandler(router.call);
  }

  /// 모든 주소의 [port]에서 요청을 받기 시작한다. 0이면 빈 포트를 고른다. 연 서버를 돌려준다.
  Future<HttpServer> serve({int? port}) async {
    final httpServer = await shelf_io.serve(createHandler(), InternetAddress.anyIPv4, port ?? environment.port);
    _httpServer = httpServer;
    final scheduler = taskScheduler;
    if (scheduler is LocalTaskScheduler) {
      scheduler.serverUri = Uri.parse('http://127.0.0.1:${httpServer.port}');
    }
    logger.info('game server 시작', {
      'mode': environment.mode.name,
      'projectId': environment.projectId,
      'port': httpServer.port,
      'callables': callables.map((endpoint) => endpoint.name).toList(),
    });
    return httpServer;
  }

  /// 요청 받기를 멈추고 남은 예약(에뮬레이터)을 취소한다.
  Future<void> close() async {
    final scheduler = taskScheduler;
    if (scheduler is LocalTaskScheduler) {
      scheduler.close();
    }
    await _httpServer?.close();
    httpClient.close();
  }
}
