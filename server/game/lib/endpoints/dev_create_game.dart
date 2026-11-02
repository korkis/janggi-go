import 'dart:math';

import 'package:janggi_core/janggi_core.dart';

import '../http/callable.dart';
import '../logging.dart';
import '../models/active_game.dart';
import '../models/game_enums.dart';
import '../repositories/configs_repository.dart';
import '../repositories/nicknames_repository.dart';
import '../repositories/users_repository.dart';
import '../services/game_rules.dart';
import '../services/game_service.dart';
import 'param_checks.dart';

/// `devCreateGame` 파라미터.
class DevCreateGameParams {
  /// 함께 둘 상대의 닉네임.
  final String opponentNickname;

  /// 부르는 사람의 진영.
  final SideChoice side;

  const DevCreateGameParams({required this.opponentNickname, required this.side});
}

/// 닉네임 최대 길이. Functions의 닉네임 규칙(`server/functions/src/config.ts`)과 같다.
const _nicknameMaxLength = 10;

/// 파라미터: `opponentNickname`(문자열), `side`(SideChoice).
DevCreateGameParams validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  final opponentNickname = params['opponentNickname'];
  if (opponentNickname is! String || opponentNickname.isEmpty || opponentNickname.length > _nicknameMaxLength) {
    throw const CallableException.invalidArgument('opponentNickname은 1~$_nicknameMaxLength자 문자열이어야 합니다');
  }
  return DevCreateGameParams(opponentNickname: opponentNickname, side: requireEnum(params, 'side', SideChoice.values));
}

/// 개발용 API. 에뮬레이터에서만 연다. 부르는 사람과 [DevCreateGameParams.opponentNickname]의 대국을 바로 만든다.
///
/// 매칭(빠른 대국, 방, 신청)이 생기기 전에 두 계정으로 한 판을 두기 위해서다(`docs/server.md`의 구현 순서 5번).
/// 급수에 반영하지 않는 신청 대국(`challenge`)으로 만든다. 결과: `gameId`.
class DevCreateGameEndpoint extends CallableEndpoint {
  final GameService gameService;
  final NicknamesRepository nicknames;
  final UsersRepository users;
  final ConfigsRepository configs;
  final GameLogger logger;

  /// 새 대국의 시간 규칙. 통합 테스트는 짧은 값을 넣는다.
  final TimeControl timeControl;

  /// 상대 찾음 화면 시간.
  final Duration matchIntro;

  /// 접속 끊김 허용 시간 합계. null이면 `configs/app.disconnectLimitSeconds`를 쓴다. 통합 테스트가 짧게 줄일 때 쓴다.
  final Duration? disconnectLimit;
  final Random _random;

  DevCreateGameEndpoint({
    required this.gameService,
    required this.nicknames,
    required this.users,
    required this.configs,
    required this.logger,
    required this.timeControl,
    required this.matchIntro,
    this.disconnectLimit,
    Random? random,
  }) : _random = random ?? Random();

  @override
  String get name => 'devCreateGame';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final params = validateParams(requestParams);
    final opponentUid = await nicknames.getUidByNickname(params.opponentNickname);
    if (opponentUid == null) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '그 닉네임의 사용자가 없습니다');
    }
    if (opponentUid == request.uid) {
      throw const CallableException.invalidArgument('자기 자신과는 둘 수 없습니다');
    }
    final opponent = await users.getUser(opponentUid);
    if (opponent == null) {
      throw const CallableException.failedPrecondition(GameErrorCode.notFound, '상대의 프로필이 없습니다');
    }
    final appConfig = await configs.getAppConfig();

    final callerSide = switch (params.side) {
      SideChoice.cho => Side.cho,
      SideChoice.han => Side.han,
      SideChoice.random => _random.nextBool() ? Side.cho : Side.han,
    };
    final caller = GamePlayer(uid: request.uid, nickname: request.user.nickname, rankLevel: request.user.rankLevel);
    final other = GamePlayer(uid: opponentUid, nickname: opponent.nickname, rankLevel: opponent.rankLevel);
    final game = createActiveGame(
      mode: GameMode.challenge,
      rated: false,
      listed: true,
      players: callerSide == Side.cho ? GamePlayers(cho: caller, han: other) : GamePlayers(cho: other, han: caller),
      timeControl: timeControl,
      disconnectLimitMs: (disconnectLimit ?? Duration(seconds: appConfig.disconnectLimitSeconds)).inMilliseconds,
      introMs: matchIntro.inMilliseconds,
      now: request.receivedAt.millisecondsSinceEpoch,
    );
    final gameId = await gameService.createGame(game, now: request.receivedAt);
    logger.info('devCreateGame 성공', {'gameId': gameId, 'uid': request.uid, 'opponentUid': opponentUid});
    return {'gameId': gameId};
  }
}
