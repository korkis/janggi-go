import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_config.dart';
import '../repositories/app_repositories.dart';
import '../utils/app_version.dart';

/// 앱 전체에 걸리는 운영 스위치(`docs/server.md`의 운영 스위치). 앱을 켤 때 `configs/app`을 한 번 읽는다.
///
/// 켜져 있는 앱의 화면은 설정이 바뀌어도 그대로다. 대국 중인 사람의 화면이 갑자기 막히지 않게 하기 위해서다. 바로 막는 것은 서버다.
/// 읽기 전이거나 읽지 못하면 막지 않는다. 설정을 읽지 못한다고 앱을 멈추지 않기 위해서다.
class AppConfigManager extends ChangeNotifier {
  /// 웹에서 돌고 있다. 테스트가 바꾼다.
  @visibleForTesting
  bool web = kIsWeb;

  AppConfig? _config;

  // 앱 버전. 읽기 전과 읽지 못했을 때는 null이다.
  String? _appVersion;

  AppConfigManager() {
    reloadForStart();
    _loadAppVersion();
  }

  bool get chatEnabled => _config?.chatEnabled ?? true;
  bool get signupEnabled => _config?.signupEnabled ?? true;
  bool get coinSaleEnabled => _config?.coinSaleEnabled ?? true;

  /// 광고는 값을 읽어야 보여준다. 읽지 못해도 앱을 쓰는 데는 지장이 없고, 멈춘 광고를 잠깐이라도 내보내지 않기 위해서다.
  bool get rewardedAdEnabled => _config?.rewardedAdEnabled ?? false;
  bool get bannerAdEnabled => _config?.bannerAdEnabled ?? false;

  /// 보상형 광고 1번의 엽전. 읽기 전이면 null이다.
  int? get coinRewardedAdReward => _config?.coinRewardedAdReward;

  /// 보상형 광고로 하루에 받을 수 있는 횟수. 읽기 전이면 null이다.
  int? get coinRewardedAdDailyLimit => _config?.coinRewardedAdDailyLimit;

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

  /// `configs/app`을 읽는다. 앱을 켤 때 한 번 부른다. 테스트는 앱을 다시 켠 것처럼 부른다.
  @visibleForTesting
  Future<void> reloadForStart() async {
    try {
      _config = await repositories.configRepository.getAppConfig();
      notifyListeners();
    } catch (error, stackTrace) {
      developer.log('ConfigRepository.getAppConfig 실패', error: error, stackTrace: stackTrace);
    }
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
