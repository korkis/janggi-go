import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../utils/app_exception.dart';
import 'ad_repository.dart';

AdRepository createAdRepository() => MobileAdRepository(adUnitIds: getAdUnitIds());

/// AdMob SDK를 쓰는 구현.
class MobileAdRepository implements AdRepository {
  // UMP 창이 닫힌 뒤 ATT 창을 띄우기까지 기다리는 시간. 앞의 창이 닫히는 중이면 iOS가 ATT 요청을 무시한다.
  static const _trackingPromptDelay = Duration(milliseconds: 200);

  /// 광고 단위. 광고를 내지 않는 빌드와 기기(데스크톱, 값을 채우지 않은 운영 빌드)이면 null이고 SDK를 부르지 않는다.
  final AdUnitIds? adUnitIds;

  MobileAdRepository({required this.adUnitIds});

  @override
  Future<bool> prepare() async {
    if (adUnitIds == null) {
      return false;
    }
    await _gatherConsent();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _requestTracking();
    }
    final allowed = await ConsentInformation.instance.canRequestAds();
    if (allowed) {
      await MobileAds.instance.initialize();
    }
    return allowed;
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    if (adUnitIds == null) {
      return false;
    }
    final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptions() async {
    final completer = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) {
        completer.completeError(StateError('showPrivacyOptionsForm 실패: ${error.errorCode} ${error.message}'));
        return;
      }
      completer.complete();
    });
    await completer.future;
  }

  @override
  Future<AdBannerHandle?> loadBanner(double width) async {
    final unitId = adUnitIds?.banner;
    if (unitId == null) {
      return null;
    }
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width.truncate());
    if (size == null) {
      return null;
    }
    final completer = Completer<AdBannerHandle?>();
    BannerAd(
      adUnitId: unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          completer.complete(
            AdBannerHandle(
              widget: AdWidget(ad: ad as AdWithView),
              width: size.width.toDouble(),
              height: size.height.toDouble(),
              dispose: ad.dispose,
            ),
          );
        },
        onAdFailedToLoad: (ad, error) {
          developer.log('BannerAd 불러오기 실패', error: '${error.code} ${error.message}');
          ad.dispose();
          completer.complete(null);
        },
      ),
    ).load();
    return completer.future;
  }

  @override
  Future<void> showRewardedAd(String uid) async {
    final ad = await _loadRewardedAd(uid);
    final closed = Completer<void>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        developer.log('RewardedAd 보여주기 실패', error: '${error.code} ${error.message}');
        ad.dispose();
        closed.completeError(const AppException(AppErrorCode.adUnavailable));
      },
    );
    // 서버 콜백의 user_id다. 보여주기 전에 정해야 한다.
    await ad.setServerSideOptions(ServerSideVerificationOptions(userId: uid));
    await ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
      },
    );
    await closed.future;
    if (!earned) {
      throw const AppException(AppErrorCode.adNotCompleted);
    }
  }

  Future<RewardedAd> _loadRewardedAd(String uid) {
    final unitId = adUnitIds?.rewarded;
    if (unitId == null) {
      throw const AppException(AppErrorCode.adUnavailable);
    }
    final completer = Completer<RewardedAd>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: completer.complete,
        onAdFailedToLoad: (error) {
          developer.log('RewardedAd 불러오기 실패', error: '${error.code} ${error.message}');
          completer.completeError(const AppException(AppErrorCode.adUnavailable));
        },
      ),
    );
    return completer.future;
  }

  /// 광고 동의 정보를 새로 읽고 필요하면 창을 띄운다(유럽 등). 앱을 켤 때마다 불러야 한다. 실패해도 지난번 동의로 이어 가므로 로그만 남긴다.
  Future<void> _gatherConsent() {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) {
            developer.log('loadAndShowConsentFormIfRequired 실패', error: '${error.errorCode} ${error.message}');
          }
          completer.complete();
        });
      },
      (error) {
        developer.log('requestConsentInfoUpdate 실패', error: '${error.errorCode} ${error.message}');
        completer.complete();
      },
    );
    return completer.future;
  }

  /// 아직 묻지 않았으면 추적 동의 창을 띄운다(`docs/monetization.md`의 광고 동의). 거절해도 광고는 나가고 광고 식별자만 빠진다.
  Future<void> _requestTracking() async {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) {
      return;
    }
    await Future<void>.delayed(_trackingPromptDelay);
    await AppTrackingTransparency.requestTrackingAuthorization();
  }
}
