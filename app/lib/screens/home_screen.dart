import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/game_scaffold.dart';
import 'setup_screen.dart';

/// 홈 화면. 1단계에서는 개발 빌드에서만 개발용 대국 시작 카드를 보여준다.
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
