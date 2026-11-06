import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// 앱만 쓰고 운영 중 바꿀 일이 없는 설정이다(`docs/dev_rules.md`의 설정 저장).

/// Functions와 대국 서버의 리전.
const functionsRegion = 'asia-northeast3';

/// 개발 빌드는 Firebase Emulator Suite에 연결한다(`docs/dev_rules.md`의 개발 환경).
/// `--dart-define=USE_FIREBASE_EMULATOR=false`로 끌 수 있다.
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: !kReleaseMode);

/// 디버그 빌드의 이메일 로그인 칸에 미리 넣는 시험 계정. 이메일의 `test` 뒤에 번호(1~4)만 치면 된다.
/// 계정은 `server/functions/src/scripts/seedEmulator.ts`가 만든다.
const debugTestEmail = 'test@janggigo.test';
const debugTestEmailCursorOffset = 4;
const debugTestPassword = 'janggigo1';

/// 에뮬레이터를 띄운 개발 PC의 주소. 실제 기기에서는 `--dart-define=FIREBASE_EMULATOR_HOST=<개발 PC IP>`로 바꾼다.
/// 안드로이드 에뮬레이터는 개발 PC를 10.0.2.2로 본다.
String getFirebaseEmulatorHost() {
  const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  if (host.isNotEmpty) {
    return host;
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return '10.0.2.2';
  }
  return 'localhost';
}

/// 에뮬레이터 포트. `server/firebase.json`의 emulators와 같다. [gameServer]는 개발 PC에서 띄운 대국 서버(`server/game`)다.
abstract final class EmulatorPorts {
  static const auth = 9099;
  static const firestore = 8080;
  static const functions = 5001;
  static const database = 9000;
  static const gameServer = 8090;
}

/// 대국 서버(`server/game`) 주소. 개발 빌드는 개발 PC의 대국 서버, 운영은 `--dart-define=GAME_SERVER_URL=<Cloud Run 주소>`다.
/// API는 이 주소 뒤에 `/<API 이름>`을 붙여 부른다(`docs/server.md`의 호출 방식).
Uri getGameServerUrl() {
  if (useFirebaseEmulator) {
    return Uri.parse('http://${getFirebaseEmulatorHost()}:${EmulatorPorts.gameServer}');
  }
  const url = String.fromEnvironment('GAME_SERVER_URL');
  if (url.isEmpty) {
    throw StateError('GAME_SERVER_URL이 없습니다');
  }
  return Uri.parse(url);
}

/// 에뮬레이터용 Firebase 설정. 프로젝트는 `server/functions`의 `npm run emulators`가 띄우는 demo 프로젝트이고,
/// demo 프로젝트는 운영 자원에 닿지 않는다. 키와 앱 ID는 에뮬레이터가 검사하지 않는 형식상의 값이다.
FirebaseOptions getEmulatorFirebaseOptions() {
  const projectId = 'demo-janggi-go';
  // 에뮬레이터는 키를 검사하지 않지만 안드로이드 Firebase SDK(Functions가 쓰는 Installations)는 실제 키 모양
  // ("AIza"로 시작하는 39자)이 아니면 요청을 보내기 전에 거절하므로 모양만 맞춘 가짜 키를 쓴다.
  const apiKey = 'AIzaSyDemoKeyForFirebaseEmulator0000000';
  const messagingSenderId = '000000000000';
  // RTDB 에뮬레이터는 이 주소의 첫 이름을 인스턴스(`ns`)로 쓴다. 대국 서버가 쓰는 `server/firebase.json`의 인스턴스와 같아야 한다.
  const databaseURL = 'https://janggi-go-default-rtdb.firebaseio.com';
  if (kIsWeb) {
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: '1:000000000000:web:0000000000000000000000',
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: '$projectId.firebaseapp.com',
      databaseURL: databaseURL,
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: '1:000000000000:ios:0000000000000000000000',
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      databaseURL: databaseURL,
      iosBundleId: 'com.gazuacup.janggigo',
    );
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    databaseURL: getAndroidEmulatorDatabaseUrl(),
  );
}

/// 안드로이드 개발 빌드의 RTDB 주소. 에뮬레이터 주소를 직접 넣는다(`http://<개발 PC>:9000?ns=<인스턴스>`).
///
/// 안드로이드에서 `useDatabaseEmulator`를 쓰면 firebase_database 플러그인이 호출마다 다른 RTDB 연결을 만들어,
/// `.info/connected`를 보는 연결이 듣는 경로 없이 60초 뒤 닫히고 다시 열리지 않는다. 주소를 직접 넣으면 연결이 하나다.
String getAndroidEmulatorDatabaseUrl() =>
    'http://${getFirebaseEmulatorHost()}:${EmulatorPorts.database}?ns=$emulatorDatabaseNamespace';

/// RTDB 에뮬레이터의 인스턴스 이름. 대국 서버가 쓰는 `server/firebase.json`의 인스턴스와 같아야 한다.
const emulatorDatabaseNamespace = 'janggi-go-default-rtdb';

/// Google 로그인의 웹 클라이언트 ID. 안드로이드에서 ID 토큰을 받으려면 필요하다.
/// Firebase 콘솔에서 Google 로그인을 켠 뒤 "웹 SDK 구성"의 웹 클라이언트 ID를
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`로 넣는다. 없으면 null이다.
String? getGoogleServerClientId() {
  const clientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  return clientId.isEmpty ? null : clientId;
}

/// 닉네임 규칙. 서버(`server/functions/src/config.ts`)와 같다. 앱은 입력하는 동안 형식만 먼저 보고,
/// 중복·금칙어·사칭은 서버의 `checkNickname`으로 확인한다.
abstract final class NicknameRules {
  static const minLength = 2;
  static const maxLength = 10;
  static final pattern = RegExp(r'^[가-힣A-Za-z0-9]+$');

  /// 닉네임을 바꾼 뒤 다시 바꿀 수 없는 기간(`docs/screens.md`의 내 정보). 서버(`NICKNAME_CHANGE_COOLDOWN_DAYS`)와 같다.
  static const changeCooldownDays = 7;

  /// 엽전 없이 바꿀 수 있는 횟수. 첫 변경만 무료이고 그 뒤에는 `configs/app.coinNicknameChangeCost`를 낸다(`docs/monetization.md`).
  static const freeChangeCount = 1;

  static bool isValidFormat(String nickname) =>
      nickname.length >= minLength && nickname.length <= maxLength && pattern.hasMatch(nickname);
}

/// 출석의 "하루"가 바뀌는 시간대의 UTC 차이. 서울 시간 0시다. Functions의 `COIN_DAY_UTC_OFFSET_HOURS`와 같다.
const coinDayUtcOffset = Duration(hours: 9);

/// 닉네임을 입력하다 멈춘 뒤 서버에 쓸 수 있는지 물어볼 때까지 기다리는 시간.
const nicknameCheckDelay = Duration(milliseconds: 400);

/// 대국 화면의 시계와 상차림 남은 시간을 다시 그리는 간격.
const gameClockTickInterval = Duration(milliseconds: 200);

/// 초대 링크 주소의 호스트. Firebase Hosting의 기본 주소다(`docs/game/matching.md`의 링크). 자체 도메인을 붙이면 바꾸고,
/// 안드로이드 App Links(`AndroidManifest.xml`)와 iOS Universal Links(`Runner.entitlements`)의 도메인도 같이 바꾼다.
/// 개발 빌드도 이 주소의 링크를 만든다.
const inviteLinkHost = 'janggi-go.web.app';

/// 초대 링크 경로의 앞부분. `https://<inviteLinkHost>/r/<방 ID>`.
const inviteLinkPathPrefix = 'r';

/// 아이폰 앱 안 브라우저의 "앱에서 열기"가 쓰는 앱 주소 scheme. `janggigo://r/<방 ID>`. `ios/Runner/Info.plist`와 같다.
const appUrlScheme = 'janggigo';

/// 운영 이메일. 제재 이의 제기(`docs/moderation.md`의 제재 단계와 안내)와 탈퇴 되돌리기(`docs/database.md`의 회원 탈퇴)를 받는다.
const supportEmail = 'playkorkis@gmail.com';

/// 플레이 스토어의 앱 주소.
const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.gazuacup.janggigo';

/// 앱스토어의 앱 주소. 앱을 등록하면 넣는다(`docs/release.md`의 운영 배포 전에 채울 값). 그 전에는 iOS의 업데이트 안내에 버튼을 두지 않는다.
const String? appStoreUrl = null;

/// 이 기기의 스토어 주소. 없으면 null이다.
String? getStoreUrl() {
  if (kIsWeb) {
    return null;
  }
  return defaultTargetPlatform == TargetPlatform.iOS ? appStoreUrl : playStoreUrl;
}

/// RevenueCat 공개 API 키(`docs/release.md`의 운영 배포 전에 채울 값). 공개 키라 앱에 넣는다.
const revenueCatGoogleApiKey = '';
const revenueCatAppleApiKey = '';

/// 이 빌드의 RevenueCat 키. 웹과 에뮬레이터 빌드는 팔지 않으므로 null이다. 에뮬레이터로는 웹훅이 오지 않아 결제해도 지급되지 않는다.
String? getRevenueCatApiKey() {
  if (kIsWeb || useFirebaseEmulator) {
    return null;
  }
  final key = defaultTargetPlatform == TargetPlatform.iOS ? revenueCatAppleApiKey : revenueCatGoogleApiKey;
  return key.isEmpty ? null : key;
}

/// 채팅 메시지 최대 글자 수. Functions의 `CHAT_MAX_LENGTH`(`server/functions/src/config.ts`)와 같다.
const chatMaxLength = 100;
