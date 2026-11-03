import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';

/// 이 기기에만 저장하는 설정(`shared_preferences`). 서버에 올리지 않으므로 기기마다 따로 정한다.
class DeviceSettingsRepository {
  /// 언어 설정 값의 키. 값은 [AppLanguage]의 `name`이다.
  static const _languageKey = 'language';

  final SharedPreferencesAsync preferences;

  DeviceSettingsRepository({required this.preferences});

  /// 저장한 언어. 저장한 적이 없거나 모르는 값이면 [AppLanguage.system]이다.
  Future<AppLanguage> getLanguage() async {
    final name = await preferences.getString(_languageKey);
    return AppLanguage.values.asNameMap()[name] ?? AppLanguage.system;
  }

  Future<void> updateLanguage(AppLanguage language) async {
    await preferences.setString(_languageKey, language.name);
  }
}
