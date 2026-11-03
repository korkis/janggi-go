import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../repositories/app_repositories.dart';
import '../models/app_language.dart';

/// 앱 언어(`docs/screens.md`의 설정). 바꾸면 앱을 다시 켜지 않아도 바로 바뀌고 기기에 저장한다.
class LanguageManager extends ChangeNotifier {
  AppLanguage _language = AppLanguage.system;

  AppLanguage get language => _language;

  /// 앱에 줄 언어. 기기 설정 따름이면 null이다.
  Locale? get locale => switch (_language) {
    AppLanguage.system => null,
    AppLanguage.ko => const Locale('ko'),
    AppLanguage.en => const Locale('en'),
  };

  /// 기기에 저장한 언어를 읽는다. 앱을 켤 때 첫 화면을 그리기 전에 부른다. 읽지 못하면 기기 설정을 따른다.
  Future<void> load() async {
    try {
      _language = await repositories.deviceSettingsRepository.getLanguage();
      notifyListeners();
    } catch (error, stackTrace) {
      developer.log('DeviceSettingsRepository.getLanguage 실패', error: error, stackTrace: stackTrace);
    }
  }

  /// 언어를 바꾸고 기기에 저장한다. 저장하지 못해도 이번 실행 동안은 바꾼 언어를 쓰고 오류를 던진다.
  Future<void> updateLanguage(AppLanguage language) async {
    if (language == _language) {
      return;
    }
    _language = language;
    notifyListeners();
    await repositories.deviceSettingsRepository.updateLanguage(language);
  }
}
