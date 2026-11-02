import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/game_enums.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/rank_format.dart';
import '../widgets/game_scaffold.dart';
import 'login_flow.dart';
import 'setup_screen.dart';

/// 홈 화면. 지금은 내 카드와, 개발 빌드에서만 보이는 개발용 대국 카드들을 보여준다.
///
/// 개발용 대국과 개발용 온라인 대국은 사용자 기능으로 내보내지 않는다(`docs/plan.md`의 로드맵).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              // 장기고
              l10n.appTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            const _ResumeGameButton(),
            const _MyCard(),
            const SizedBox(height: 16),
            if (!kReleaseMode) const _DevGameCard(),
            if (!kReleaseMode) ...[const SizedBox(height: 16), const _DevOnlineGameCard()],
          ],
        ),
      ),
    );
  }
}

/// 진행 중인 온라인 대국이 있으면(앱이 꺼졌다 켜진 경우 등) 맨 위에 "대국으로 돌아가기"를 보여준다
/// (`docs/screens.md`의 홈). 상차림 화면으로 열고, 상차림이 끝난 대국이면 상차림 화면이 바로 대국 화면으로 넘긴다.
class _ResumeGameButton extends StatelessWidget {
  const _ResumeGameButton();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([managers.authManager, managers.playerStateManager]),
      builder: _buildButton,
    );
  }

  Widget _buildButton(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final gameId = managers.playerStateManager.gameId;
    if (managers.authManager.profile == null || gameId == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FilledButton.icon(
        onPressed: () => _onResume(context, gameId),
        icon: const Icon(Icons.play_arrow),
        // 대국으로 돌아가기
        label: Text(l10n.homeResumeGame),
      ),
    );
  }

  void _onResume(BuildContext context, String gameId) {
    Navigator.of(context).push(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
  }
}

class _DevGameCard extends StatelessWidget {
  const _DevGameCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // 개발용 대국
              l10n.homeDevGameTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              // 한 기기에서 초와 한을 번갈아 둬요
              l10n.homeDevGameDescription,
              style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _onStart(context),
              // 시작하기
              child: Text(l10n.homeDevGameStart),
            ),
          ],
        ),
      ),
    );
  }

  void _onStart(BuildContext context) {
    Navigator.of(context).push(createGameRoute<void>((context) => const SetupScreen()));
  }
}

/// 개발용 온라인 대국 카드. 매칭이 생기기 전에 두 계정으로 한 판을 두기 위해 상대 닉네임으로 대국을 바로 만든다.
///
/// 대국은 대국 서버의 개발용 API(`devCreateGame`)가 만들고, 두 사람의 `player_states.gameId`가 생기면 홈에 있던 앱은
/// 상차림으로 넘어간다. 로그인하고 닉네임을 정한 뒤에만 보인다.
class _DevOnlineGameCard extends StatefulWidget {
  const _DevOnlineGameCard();

  @override
  State<_DevOnlineGameCard> createState() => _DevOnlineGameCardState();
}

class _DevOnlineGameCardState extends State<_DevOnlineGameCard> {
  final _opponentController = TextEditingController();
  var _side = SideChoice.random;
  var _creating = false;

  // 이미 연 대국. 같은 대국을 두 번 열지 않는다.
  String? _openedGameId;

  @override
  void initState() {
    super.initState();
    _openedGameId = managers.playerStateManager.gameId;
    managers.playerStateManager.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    managers.playerStateManager.removeListener(_onPlayerStateChanged);
    _opponentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([managers.authManager, managers.playerStateManager]),
      builder: _buildContent,
    );
  }

  Widget _buildContent(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    if (managers.authManager.profile == null) {
      return const SizedBox.shrink();
    }
    // 진행 중인 대국은 맨 위의 "대국으로 돌아가기"로 간다.
    if (managers.playerStateManager.gameId != null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // 개발용 온라인 대국
              l10n.homeDevOnlineTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              // 상대 닉네임을 넣으면 두 계정의 대국을 바로 만들어요
              l10n.homeDevOnlineDescription,
              style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _opponentController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                // 상대 닉네임
                labelText: l10n.homeDevOnlineOpponent,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<SideChoice>(
              segments: [
                for (final side in SideChoice.values)
                  ButtonSegment(
                    value: side,
                    // 초 / 한 / 무작위
                    label: Text(l10n.sideChoiceName(side.name)),
                  ),
              ],
              selected: {_side},
              onSelectionChanged: _onSideChanged,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _creating ? null : _onCreate,
              // 대국 만들기
              child: Text(l10n.homeDevOnlineCreate),
            ),
          ],
        ),
      ),
    );
  }

  void _onSideChanged(Set<SideChoice> selected) {
    setState(() {
      _side = selected.single;
    });
  }

  Future<void> _onCreate() async {
    final opponentNickname = _opponentController.text.trim();
    if (opponentNickname.isEmpty) {
      return;
    }
    try {
      setState(() {
        _creating = true;
      });
      await repositories.gameRepository.createDevGame(opponentNickname: opponentNickname, side: _side);
    } catch (error, stackTrace) {
      developer.log('GameRepository.createDevGame 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 대국을 만들지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorCreateGame;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  /// 새 대국이 생기면 홈이 맨 위에 있을 때 상차림으로 간다. 다른 화면에 있으면 홈의 "대국으로 돌아가기"로 간다.
  void _onPlayerStateChanged() {
    final gameId = managers.playerStateManager.gameId;
    if (gameId == null || gameId == _openedGameId || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    _openGame(gameId);
  }

  void _openGame(String gameId) {
    _openedGameId = gameId;
    Navigator.of(context).push(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
  }
}

/// 내 카드. 로그인하지 않았으면 로그인 버튼과 안내를 둔다(`docs/screens.md`의 로그인).
class _MyCard extends StatelessWidget {
  const _MyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListenableBuilder(listenable: managers.authManager, builder: _buildContent),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final authManager = managers.authManager;
    final profile = authManager.profile;
    if (authManager.profileLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profile == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            // 로그인하면 급수와 전적이 저장돼요
            l10n.homeLoginGuide,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _onLogin(context),
            // 로그인
            child: Text(l10n.login),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(profile.nickname, style: Theme.of(context).textTheme.titleLarge),
        Text(
          getRankLabel(l10n, profile.rankLevel),
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
        if (!kReleaseMode)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _onSignOut(context),
              // 로그아웃 (개발용)
              child: Text(l10n.homeDevSignOut),
            ),
          ),
      ],
    );
  }

  Future<void> _onLogin(BuildContext context) async {
    await ensureSignedInWithProfile(context, LoginPurpose.home);
  }

  Future<void> _onSignOut(BuildContext context) async {
    try {
      await managers.authManager.signOut();
    } catch (error, stackTrace) {
      developer.log('AuthManager.signOut 실패', error: error, stackTrace: stackTrace);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        // 로그아웃하지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: l10n.errorSignOut);
      }
    }
  }
}
