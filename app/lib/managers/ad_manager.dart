import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../repositories/ad_repository.dart';
import '../repositories/app_repositories.dart';
import 'app_config_manager.dart';
import 'auth_manager.dart';
import 'coin_manager.dart';
import 'store_manager.dart';

/// 앱 광고(`docs/monetization.md`의 광고 위치, 광고 제거). 배너와 보상형 광고를 지금 보여줘도 되는지 정한다.
///
/// 웹, 동의를 받지 못한 사람, `configs/app`을 읽기 전이면 광고가 없다. 광고 제거는 배너만 없앤다.
class AdManager extends ChangeNotifier {
  final AuthManager authManager;
  final AppConfigManager appConfigManager;
  final StoreManager storeManager;
  final CoinManager coinManager;

  late final Listenable _dependencies = Listenable.merge([authManager, appConfigManager, storeManager, coinManager]);

  // 동의를 거쳐 광고를 요청할 수 있다.
  var _adsAllowed = false;
  var _privacyOptionsRequired = false;
  var _rewardedAdShowing = false;

  AdManager({
    required this.authManager,
    required this.appConfigManager,
    required this.storeManager,
    required this.coinManager,
  }) {
    _dependencies.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _dependencies.removeListener(notifyListeners);
    super.dispose();
  }

  /// 설정에 광고 개인정보 항목을 둔다.
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// 보상형 광고를 불러오거나 보여주는 중이다.
  bool get rewardedAdShowing => _rewardedAdShowing;

  /// 하단 배너를 보여준다. 보관함을 읽기 전에는 광고 제거를 샀는지 모르므로 보여주지 않는다.
  bool get bannerVisible {
    return _adsAllowed &&
        !appConfigManager.onWeb &&
        appConfigManager.bannerAdEnabled &&
        storeManager.inventoryLoaded &&
        !storeManager.adsRemoved;
  }

  /// 보상형 광고 1번의 엽전. 이 사람이 볼 수 없으면(웹, 로그아웃, 스위치 꺼짐, 동의 없음) null이고 버튼을 두지 않는다.
  int? get rewardedAdReward {
    if (!_adsAllowed || appConfigManager.onWeb || !appConfigManager.rewardedAdEnabled || authManager.uid == null) {
      return null;
    }
    return appConfigManager.coinRewardedAdReward;
  }

  /// 오늘 더 받을 수 있는 횟수. 값을 읽지 못했으면 null이다. 서버가 다시 판단하므로 기기 시계가 틀려도 더 받지 못한다.
  int? get rewardedAdsLeft {
    final limit = appConfigManager.coinRewardedAdDailyLimit;
    final watched = coinManager.rewardedAdsToday;
    if (limit == null || watched == null) {
      return null;
    }
    return max(0, limit - watched);
  }

  /// 지금 보상형 광고 버튼을 눌러도 된다.
  bool get rewardedAdWatchable => rewardedAdReward != null && (rewardedAdsLeft ?? 0) > 0;

  /// 동의를 받고 광고를 켠다. 첫 화면이 뜬 뒤 `main()`이 한 번 부른다. 실패하면 이번 실행에는 광고 없이 간다.
  Future<void> start() async {
    try {
      _adsAllowed = await repositories.adRepository.prepare();
      _privacyOptionsRequired = await repositories.adRepository.isPrivacyOptionsRequired();
      notifyListeners();
    } catch (error, stackTrace) {
      developer.log('AdRepository.prepare 실패', error: error, stackTrace: stackTrace);
    }
  }

  /// 광고 동의를 다시 고른다. 동의를 거두면 다음에 켤 때 SDK가 알려 주므로 그때 광고가 멈춘다.
  Future<void> showPrivacyOptions() => repositories.adRepository.showPrivacyOptions();

  /// 보상형 광고를 보여주고 닫힐 때까지 기다린다. 엽전은 서버가 주고 지갑을 듣는 쪽에 들어온다.
  Future<void> showRewardedAd() async {
    final uid = authManager.uid;
    if (uid == null) {
      throw StateError('로그인하지 않고 볼 수 없습니다');
    }
    try {
      _rewardedAdShowing = true;
      notifyListeners();
      await repositories.adRepository.showRewardedAd(uid);
    } finally {
      _rewardedAdShowing = false;
      notifyListeners();
    }
  }

  /// 폭 [width]의 배너를 불러온다. 위젯이 쓰고 [AdBannerHandle.dispose]한다.
  Future<AdBannerHandle?> loadBanner(double width) => repositories.adRepository.loadBanner(width);
}
