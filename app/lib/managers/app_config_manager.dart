import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_config.dart';
import '../repositories/app_repositories.dart';
import '../utils/app_version.dart';

/// 앱 전체에 걸리는 운영 스위치(`docs/server.md`의 운영 스위치). `configs/app`을 계속 듣는다.
///
/// 읽기 전이거나 읽지 못하면 막지 않는다. 설정을 읽지 못한다고 앱을 멈추지 않기 위해서다. 바로 막는 것은 서버다.
class AppConfigManager extends ChangeNotifier {
  /// 웹에서 돌고 있다. 테스트가 바꾼다.
  @visibleForTesting
  bool web = kIsWeb;

  StreamSubscription<AppConfig?>? _subscription;
  AppConfig? _config;

  // 앱 버전. 읽기 전과 읽지 못했을 때는 null이다.
  String? _appVersion;

  AppConfigManager() {
    _subscription = repositories.configRepository.watchAppConfig().listen(_onConfigChanged, onError: _onConfigError);
    _loadAppVersion();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get chatEnabled => _config?.chatEnabled ?? true;
  bool get signupEnabled => _config?.signupEnabled ?? true;
  bool get coinSaleEnabled => _config?.coinSaleEnabled ?? true;

  /// 웹이다. 상점에서 팔지 않는다.
  bool get onWeb => web;

  /// 웹이고 `webEnabled`가 꺼져 있다. 안내 화면만 보여준다.
  bool get webClosed => web && _config?.webEnabled == false;

  /// 앱(안드로이드, iOS)이 `minAppVersion`보다 낮다. 업데이트 화면만 보여준다.
  bool get updateRequired {
    final appVersion = _appVersion;
    final minAppVersion = _config?.minAppVersion;
    return !web && appVersion != null && minAppVersion != null && isOlderVersion(appVersion, minAppVersion);
  }

  /// 공지. 없으면 null이다.
  ServiceNotice? get serviceNotice => _config?.serviceNotice;

  void _onConfigChanged(AppConfig? config) {
    _config = config;
    notifyListeners();
  }

  void _onConfigError(Object error, StackTrace stackTrace) {
    developer.log('AppConfigManager 듣기 실패', error: error, stackTrace: stackTrace);
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      notifyListeners();
    } catch (error, stackTrace) {
      developer.log('PackageInfo.fromPlatform 실패', error: error, stackTrace: stackTrace);
    }
  }
}
