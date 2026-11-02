import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class JanggigoApp extends StatelessWidget {
  const JanggigoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: _getTitle,
      theme: lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    );
  }

  String _getTitle(BuildContext context) {
    // 장기고
    return AppLocalizations.of(context).appTitle;
  }
}
