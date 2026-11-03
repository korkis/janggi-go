import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Auth 에뮬레이터 주소를 Firebase 초기화 전에 sessionStorage에 적어 둔다.
///
/// firebase_auth_web은 초기화하면서 저장된 로그인을 되살리고, 토큰이 만료됐으면 바로 새로 받는다. 이때 sessionStorage에
/// 에뮬레이터 주소가 있어야 에뮬레이터로 보낸다. sessionStorage는 탭마다 따로라 새 탭에서는 비어 있고, 그러면 운영 Google
/// 서버로 보내 실패한다("couldn't load your profile"). 키 이름은 firebase_auth_web의 authEmulatorOriginStorageKey와 같다.
void rememberAuthEmulatorOrigin(String appName, String origin) {
  final storage = globalContext.getProperty<JSObject>('sessionStorage'.toJS);
  storage.callMethod<JSAny?>('setItem'.toJS, '$appName-firebaseEmulatorOrigin'.toJS, origin.toJS);
}
