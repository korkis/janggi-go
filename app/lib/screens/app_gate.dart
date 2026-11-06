import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../theme/app_theme.dart';

/// 운영 스위치가 앱 전체를 막으면 [child] 대신 안내 화면을 보여준다(`docs/screens.md`의 업데이트 안내와 웹 안내).
class AppGate extends StatelessWidget {
  final Widget child;

  const AppGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: managers.appConfigManager, builder: _buildGate, child: child);
  }

  Widget _buildGate(BuildContext context, Widget? child) {
    final config = managers.appConfigManager;
    if (config.webClosed) {
      return const _WebClosedScreen();
    }
    if (config.updateRequired) {
      return const _UpdateRequiredScreen();
    }
    return child ?? const SizedBox.shrink();
  }
}

class _GateMessage extends StatelessWidget {
  final String message;
  final Widget? action;

  const _GateMessage({required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w700),
                ),
                if (action != null) ...[const SizedBox(height: 24), action],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebClosedScreen extends StatelessWidget {
  const _WebClosedScreen();

  @override
  Widget build(BuildContext context) {
    // 지금은 웹에서 이용할 수 없어요. 앱을 이용해 주세요
    return _GateMessage(message: AppLocalizations.of(context).webClosedMessage);
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _GateMessage(
      // 새 버전으로 업데이트해 주세요
      message: l10n.updateRequiredMessage,
      action: getStoreUrl() == null
          ? null
          : FilledButton(
              onPressed: _onUpdate,
              // 업데이트
              child: Text(l10n.updateRequiredButton),
            ),
    );
  }

  Future<void> _onUpdate() async {
    final url = getStoreUrl();
    if (url == null) {
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error, stackTrace) {
      developer.log('launchUrl 실패', error: error, stackTrace: stackTrace);
    }
  }
}
