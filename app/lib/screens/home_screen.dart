import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../theme/app_theme.dart';
import '../utils/dialog_utils.dart';
import '../utils/rank_format.dart';
import '../widgets/game_scaffold.dart';
import 'login_flow.dart';
import 'setup_screen.dart';

/// 홈 화면. 지금은 내 카드와, 개발 빌드에서만 보이는 개발용 대국 시작 카드를 보여준다.
///
/// 개발용 대국은 사용자 기능으로 내보내지 않는다(`docs/plan.md`의 로드맵).
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
            const _MyCard(),
            const SizedBox(height: 16),
            if (!kReleaseMode) const _DevGameCard(),
          ],
        ),
      ),
    );
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
