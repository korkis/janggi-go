import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../repositories/app_repositories.dart';

/// 효과음과 진동을 켜고 끄는 설정(`docs/screens.md`의 설정). 기기에 저장한다. 실제 재생은 효과음과 진동 구현(구현 순서 7번)에서
/// 이 값을 읽는다.
class EffectSettingsManager extends ChangeNotifier {
  var _soundEnabled = true;
  var _vibrationEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  /// 기기에 저장한 값을 읽는다. 앱을 켤 때 첫 화면을 그리기 전에 부른다. 읽지 못하면 켜 둔다.
  Future<void> load() async {
    try {
      final deviceSettings = repositories.deviceSettingsRepository;
      final (soundEnabled, vibrationEnabled) = await (
        deviceSettings.getSoundEnabled(),
        deviceSettings.getVibrationEnabled(),
      ).wait;
      _soundEnabled = soundEnabled;
      _vibrationEnabled = vibrationEnabled;
      notifyListeners();
    } catch (error, stackTrace) {
      developer.log('EffectSettingsManager.load 실패', error: error, stackTrace: stackTrace);
    }
  }

  /// 저장하지 못해도 이번 실행 동안은 바꾼 값을 쓰고 오류를 던진다.
  Future<void> updateSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    notifyListeners();
    await repositories.deviceSettingsRepository.updateSoundEnabled(enabled);
  }

  /// 저장하지 못해도 이번 실행 동안은 바꾼 값을 쓰고 오류를 던진다.
  Future<void> updateVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    notifyListeners();
    await repositories.deviceSettingsRepository.updateVibrationEnabled(enabled);
  }
}
