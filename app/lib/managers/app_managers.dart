import 'auth_manager.dart';
import 'block_manager.dart';
import 'challenge_manager.dart';
import 'coin_manager.dart';
import 'connection_manager.dart';
import 'effect_settings_manager.dart';
import 'invite_link_manager.dart';
import 'language_manager.dart';
import 'lobby_presence_manager.dart';
import 'player_state_manager.dart';
import 'rank_manager.dart';
import 'sanction_manager.dart';

/// 앱 수명 동안 유지하는 Manager. `repositories`를 설정한 뒤에 설정한다.
late AppManagers managers;

class AppManagers {
  final AuthManager authManager;
  final PlayerStateManager playerStateManager;
  final ConnectionManager connectionManager;
  final RankManager rankManager;
  final InviteLinkManager inviteLinkManager;
  final LobbyPresenceManager lobbyPresenceManager;
  final ChallengeManager challengeManager;
  final BlockManager blockManager;
  final SanctionManager sanctionManager;
  final LanguageManager languageManager;
  final EffectSettingsManager effectSettingsManager;
  final CoinManager coinManager;

  AppManagers({
    required this.authManager,
    required this.playerStateManager,
    required this.connectionManager,
    required this.rankManager,
    required this.inviteLinkManager,
    required this.lobbyPresenceManager,
    required this.challengeManager,
    required this.blockManager,
    required this.sanctionManager,
    required this.languageManager,
    required this.effectSettingsManager,
    required this.coinManager,
  });

  factory AppManagers.createDefault() {
    final authManager = AuthManager();
    final playerStateManager = PlayerStateManager(authManager: authManager);
    final connectionManager = ConnectionManager(authManager: authManager, playerStateManager: playerStateManager);
    return AppManagers(
      authManager: authManager,
      playerStateManager: playerStateManager,
      connectionManager: connectionManager,
      rankManager: RankManager(authManager: authManager),
      inviteLinkManager: InviteLinkManager(),
      lobbyPresenceManager: LobbyPresenceManager(authManager: authManager, connectionManager: connectionManager),
      challengeManager: ChallengeManager(playerStateManager: playerStateManager),
      blockManager: BlockManager(authManager: authManager),
      sanctionManager: SanctionManager(authManager: authManager),
      languageManager: LanguageManager(),
      effectSettingsManager: EffectSettingsManager(),
      coinManager: CoinManager(authManager: authManager),
    );
  }
}
