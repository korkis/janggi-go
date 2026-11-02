import 'package:firebase_core/firebase_core.dart';

/// 운영 프로젝트(janggi-go)의 앱 설정.
///
/// 아직 Firebase에 앱을 등록하지 않았다. 등록한 뒤 `flutterfire configure --project=janggi-go`로
/// 이 파일을 다시 만든다. 그 전에는 에뮬레이터에 연결하는 개발 빌드만 실행할 수 있다.
abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError('운영 Firebase 설정이 없습니다. flutterfire configure로 firebase_options.dart를 만들어야 합니다');
  }
}
