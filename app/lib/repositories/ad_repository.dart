import 'package:flutter/widgets.dart';

/// 불러온 배너 광고 하나. 쓰고 나면 [dispose]한다.
class AdBannerHandle {
  final Widget widget;
  final double width;
  final double height;
  final VoidCallback dispose;

  const AdBannerHandle({required this.widget, required this.width, required this.height, required this.dispose});
}

/// 앱 광고(AdMob, `docs/monetization.md`). 웹은 광고가 없고 구현이 아무것도 하지 않는다.
abstract interface class AdRepository {
  /// 광고 동의(UMP)와 iOS 추적 동의(ATT)를 받고 SDK를 켠다. 광고를 요청할 수 있으면 true다. 앱을 켤 때 한 번 부른다.
  Future<bool> prepare();

  /// 설정에 광고 개인정보 항목을 두어야 한다(유럽 등 UMP 대상).
  Future<bool> isPrivacyOptionsRequired();

  /// 광고 동의를 다시 고르는 창을 띄운다.
  Future<void> showPrivacyOptions();

  /// 폭 [width]의 하단 배너를 불러온다. 광고가 없으면 null이다.
  Future<AdBannerHandle?> loadBanner(double width);

  /// [uid]로 보상형 광고를 불러와 보여주고 닫힐 때까지 기다린다. 끝까지 보지 않았으면 `adNotCompleted`, 보여줄 수 없으면 `adUnavailable`을
  /// 던진다. 엽전은 AdMob이 부르는 서버 콜백이 준다(`docs/server.md`의 앱 광고).
  Future<void> showRewardedAd(String uid);
}
