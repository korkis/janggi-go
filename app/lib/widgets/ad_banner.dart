import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../managers/app_managers.dart';
import '../repositories/ad_repository.dart';

/// 하단 배너(`docs/monetization.md`의 광고 위치). 광고가 들어와야 자리를 차지하고, 보여주지 않을 때는 아무 자리도 쓰지 않는다.
///
/// 위아래 여백은 버튼과 떨어뜨려 잘못 누르지 않게 하기 위해서다.
class AdBanner extends StatefulWidget {
  static const _verticalMargin = 8.0;

  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  AdBannerHandle? _banner;

  // 불러온 폭이나 불러오는 중인 폭. 폭이 바뀌면(화면 회전) 다시 불러온다.
  double? _requestedWidth;

  // 가장 최근 요청. 응답이 늦게 온 옛 요청의 광고는 버린다.
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    managers.adManager.addListener(_onAdsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 창 크기가 바뀌면 다시 부른다. 그린 뒤에 폭을 잰다.
    MediaQuery.sizeOf(context);
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  @override
  void dispose() {
    managers.adManager.removeListener(_onAdsChanged);
    _requestId++;
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (banner == null) {
      return const SizedBox(width: double.infinity);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AdBanner._verticalMargin),
      child: Center(
        heightFactor: 1,
        child: SizedBox(width: banner.width, height: banner.height, child: banner.widget),
      ),
    );
  }

  void _onFrame(Duration timeStamp) {
    if (mounted) {
      _syncBanner();
    }
  }

  /// 다음 화면을 그린 뒤에 맞춘다. 폭은 배치가 끝나야 잴 수 있다.
  void _onAdsChanged() {
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// 보여줄 때가 되면 불러오고, 그만 보여줄 때(광고 제거를 샀다, 동의를 거뒀다)가 되면 치운다.
  void _syncBanner() {
    if (!managers.adManager.bannerVisible) {
      _removeBanner();
      return;
    }
    final width = context.size?.width;
    if (width != null && width > 0 && width != _requestedWidth) {
      _loadBanner(width);
    }
  }

  void _removeBanner() {
    _requestId++;
    _requestedWidth = null;
    final banner = _banner;
    if (banner != null) {
      banner.dispose();
      setState(() {
        _banner = null;
      });
    }
  }

  Future<void> _loadBanner(double width) async {
    final requestId = ++_requestId;
    _requestedWidth = width;
    try {
      final banner = await managers.adManager.loadBanner(width);
      if (!mounted || requestId != _requestId) {
        banner?.dispose();
        return;
      }
      final previous = _banner;
      setState(() {
        _banner = banner;
      });
      previous?.dispose();
    } catch (error, stackTrace) {
      developer.log('AdManager.loadBanner 실패', error: error, stackTrace: stackTrace);
    }
  }
}
