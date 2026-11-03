import '../logging.dart';
import '../models/game_enums.dart';
import '../models/online_user.dart';
import '../models/user.dart';
import '../repositories/online_users_repository.dart';
import '../repositories/player_states_repository.dart';
import '../repositories/users_private_repository.dart';

/// 대국실 접속자 목록(`docs/server.md`의 접속자 목록). RTDB `online_users`에 로그인하고 앱을 화면에 켜 둔 사람을 둔다.
///
/// 앱은 RTDB에 연결되거나 화면에 돌아올 때마다 [enterLobby]를 부르고 자기 항목에 `onDisconnect`로 삭제를 걸어 둔다. 대국이
/// 생기고 끝날 때의 상태는 `GameService`가 따라 쓴다.
class LobbyService {
  final OnlineUsersRepository onlineUsers;
  final PlayerStatesRepository playerStates;
  final UsersPrivateRepository usersPrivate;
  final GameLogger logger;

  const LobbyService({
    required this.onlineUsers,
    required this.playerStates,
    required this.usersPrivate,
    required this.logger,
  });

  /// [uid]의 `online_users` 항목을 지금 닉네임, 급수, 상태, 신청 받기로 쓴다. 이미 있으면 새로 쓴다.
  ///
  /// 상태는 진행 중 대국(`player_states.gameId`)이 있으면 `playing`이다. 신청 받기는 `users_private.challengesEnabled`이고
  /// 문서가 없으면(프로필을 만드는 중) 받지 않는 것으로 쓴다.
  Future<void> enterLobby(String uid, User user, {required DateTime now}) async {
    final (state, private) = await (playerStates.getPlayerState(uid), usersPrivate.getUserPrivate(uid)).wait;
    if (private == null) {
      logger.warning('users_private가 없어 신청 받기를 끈 것으로 씁니다', {'uid': uid});
    }
    final status = state?.gameId == null ? OnlineStatus.waiting : OnlineStatus.playing;
    await onlineUsers.setOnlineUser(
      uid,
      OnlineUser(
        nickname: user.nickname,
        rankLevel: user.rankLevel,
        status: status,
        challengesEnabled: private?.challengesEnabled ?? false,
        since: now.millisecondsSinceEpoch,
      ),
    );
    logger.info('enterLobby 성공', {'uid': uid, 'status': status.name});
  }
}
