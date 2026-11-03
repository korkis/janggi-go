import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/app_language.dart';
import '../theme/app_theme.dart';
import '../utils/dialog_utils.dart';
import '../widgets/adaptive_layout.dart';

/// 설정(`docs/screens.md`의 설정). 내 정보에서 연다.
///
/// 지금은 언어만 둔다. 기기 설정 따름(기본), 한국어, English 가운데 고르면 앱을 다시 켜지 않아도 바로 바뀌고 기기에 저장한다.
/// 소리, 진동, 대국 신청 받기, 계정, 정보 묶음은 그 기능이 생기면 넣는다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      layout: PageLayout.wide,
      child: Scaffold(
        appBar: AppBar(
          // 설정
          title: Text(l10n.menuSettings),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  // 언어
                  l10n.settingsLanguage,
                  style: const TextStyle(
                    fontSize: AppTextSizes.body,
                    fontWeight: FontWeight.w700,
                    color: LightColors.subText,
                  ),
                ),
              ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListenableBuilder(listenable: managers.languageManager, builder: _buildLanguages),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguages(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    return RadioGroup<AppLanguage>(
      groupValue: managers.languageManager.language,
      onChanged: _onLanguageChanged,
      child: Column(
        children: [
          for (final language in AppLanguage.values)
            RadioListTile<AppLanguage>(
              value: language,
              title: Text(getLanguageLabel(l10n, language), style: const TextStyle(fontSize: AppTextSizes.body)),
            ),
        ],
      ),
    );
  }

  Future<void> _onLanguageChanged(AppLanguage? language) async {
    if (language == null) {
      return;
    }
    try {
      await managers.languageManager.updateLanguage(language);
    } catch (error, stackTrace) {
      developer.log('LanguageManager.updateLanguage 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 설정을 저장하지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: AppLocalizations.of(context).errorSaveSettings);
      }
    }
  }
}

/// 설정의 언어 선택지 이름. 언어 이름은 그 언어로 쓴다.
String getLanguageLabel(AppLocalizations l10n, AppLanguage language) => switch (language) {
  // 기기 설정 따름
  AppLanguage.system => l10n.languageSystem,
  // 한국어
  AppLanguage.ko => l10n.languageKorean,
  // English
  AppLanguage.en => l10n.languageEnglish,
};
