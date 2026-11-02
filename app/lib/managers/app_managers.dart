import 'auth_manager.dart';
import 'player_state_manager.dart';

/// 앱 수명 동안 유지하는 Manager. `repositories`를 설정한 뒤에 설정한다.
late AppManagers managers;

class AppManagers {
  final AuthManager authManager;
  final PlayerStateManager playerStateManager;

  AppManagers({required this.authManager, required this.playerStateManager});

  factory AppManagers.createDefault() {
    final authManager = AuthManager();
    return AppManagers(
      authManager: authManager,
      playerStateManager: PlayerStateManager(authManager: authManager),
    );
  }
}
