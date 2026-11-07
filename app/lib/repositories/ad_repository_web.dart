import 'ad_repository.dart';

/// 웹은 광고 없이 공개한다(`docs/monetization.md`의 웹 광고). 광고 SDK가 웹을 지원하지 않아 불러오지도 않는다.
AdRepository createAdRepository() => _NoAdRepository();

class _NoAdRepository implements AdRepository {
  @override
  Future<bool> prepare() async => false;

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<AdBannerHandle?> loadBanner(double width) async => null;

  @override
  Future<void> showRewardedAd(String uid) => throw StateError('웹에는 광고가 없습니다');
}
