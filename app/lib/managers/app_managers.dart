import 'auth_manager.dart';
import 'connection_manager.dart';
import 'player_state_manager.dart';
import 'rank_manager.dart';

/// 앱 수명 동안 유지하는 Manager. `repositories`를 설정한 뒤에 설정한다.
late AppManagers managers;

class AppManagers {
  final AuthManager authManager;
  final PlayerStateManager playerStateManager;
  final ConnectionManager connectionManager;
  final RankManager rankManager;

  AppManagers({
    required this.authManager,
    required this.playerStateManager,
    required this.connectionManager,
    required this.rankManager,
  });

  factory AppManagers.createDefault() {
    final authManager = AuthManager();
    final playerStateManager = PlayerStateManager(authManager: authManager);
    return AppManagers(
      authManager: authManager,
      playerStateManager: playerStateManager,
      connectionManager: ConnectionManager(authManager: authManager, playerStateManager: playerStateManager),
      rankManager: RankManager(authManager: authManager),
    );
  }
}
