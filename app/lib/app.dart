import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'managers/app_managers.dart';
import 'screens/app_gate.dart';
import 'screens/attendance_listener.dart';
import 'screens/home_screen.dart';
import 'screens/incoming_challenge_dialog.dart';
import 'screens/sanction_dialog.dart';
import 'screens/service_notice_dialog.dart';
import 'theme/app_theme.dart';
import 'widgets/adaptive_layout.dart';

class JanggigoApp extends StatefulWidget {
  const JanggigoApp({super.key});

  @override
  State<JanggigoApp> createState() => _JanggigoAppState();
}

class _JanggigoAppState extends State<JanggigoApp> {
  // 받은 대국 신청 팝업과 제재 팝업을 어느 화면 위에든 띄우기 위한 Navigator.
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // 설정에서 언어를 바꾸면 앱을 다시 켜지 않아도 바로 바뀐다(`docs/screens.md`의 설정).
    return ListenableBuilder(listenable: managers.languageManager, builder: _buildMaterialApp);
  }

  Widget _buildMaterialApp(BuildContext context, Widget? child) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [pageRouteObserver],
      onGenerateTitle: _getTitle,
      theme: lightTheme,
      locale: managers.languageManager.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: _buildApp,
      home: const HomeScreen(),
    );
  }

  String _getTitle(BuildContext context) {
    // 장기고
    return AppLocalizations.of(context).appTitle;
  }

  Widget _buildApp(BuildContext context, Widget? child) {
    return AppGate(
      child: AttendanceListener(
        child: SanctionListener(
          navigatorKey: _navigatorKey,
          child: ServiceNoticeListener(
            navigatorKey: _navigatorKey,
            child: ChallengeListener(navigatorKey: _navigatorKey, child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
