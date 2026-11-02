import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 앱으로 들어오는 주소(안드로이드 App Links, iOS Universal Links와 앱 주소 scheme, 웹의 처음 주소)와 안드로이드 플레이 스토어
/// 설치 정보. DB가 아닌 플랫폼에서 받는 값이지만 화면과 Manager가 테스트에서 바꿔 끼울 수 있게 repository로 둔다.
class DeepLinkRepository {
  final AppLinks appLinks;

  DeepLinkRepository({required this.appLinks});

  /// 안드로이드 `MainActivity`의 설치 정보 채널.
  static const _installReferrerChannel = MethodChannel('janggigo/install_referrer');

  /// 앱을 연 주소와 그 뒤에 들어오는 주소를 보낸다. 웹은 처음 주소만 보낸다.
  Stream<Uri> watchLinks() => appLinks.uriLinkStream;

  /// 플레이 스토어 설치 정보(`referrer`)를 설치 뒤 처음 한 번만 돌려준다. 이미 읽었거나 안드로이드가 아니면 null.
  /// 한 번 읽었다는 기록은 안드로이드 쪽이 남긴다.
  Future<String?> takeInstallReferrer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    return _installReferrerChannel.invokeMethod<String>('takeInstallReferrer');
  }
}
