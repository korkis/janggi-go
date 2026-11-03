import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/incoming_challenge_dialog.dart';
import 'theme/app_theme.dart';

class JanggigoApp extends StatefulWidget {
  const JanggigoApp({super.key});

  @override
  State<JanggigoApp> createState() => _JanggigoAppState();
}

class _JanggigoAppState extends State<JanggigoApp> {
  // 받은 대국 신청 팝업을 어느 화면 위에든 띄우기 위한 Navigator.
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: _getTitle,
      theme: lightTheme,
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
    return ChallengeListener(navigatorKey: _navigatorKey, child: child ?? const SizedBox.shrink());
  }
}
