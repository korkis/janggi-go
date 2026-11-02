import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// 앱만 쓰고 운영 중 바꿀 일이 없는 설정이다(`docs/dev_rules.md`의 설정 저장).

/// Functions와 대국 서버의 리전.
const functionsRegion = 'asia-northeast3';

/// 개발 빌드는 Firebase Emulator Suite에 연결한다(`docs/dev_rules.md`의 개발 환경).
/// `--dart-define=USE_FIREBASE_EMULATOR=false`로 끌 수 있다.
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: !kReleaseMode);

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

/// 에뮬레이터 포트. `server/firebase.json`의 emulators와 같다.
abstract final class EmulatorPorts {
  static const auth = 9099;
  static const firestore = 8080;
  static const functions = 5001;
}

/// 에뮬레이터용 Firebase 설정. 프로젝트는 `server/functions`의 `npm run emulators`가 띄우는 demo 프로젝트이고,
/// demo 프로젝트는 운영 자원에 닿지 않는다. 키와 앱 ID는 에뮬레이터가 검사하지 않는 형식상의 값이다.
FirebaseOptions getEmulatorFirebaseOptions() {
  const projectId = 'demo-janggi-go';
  const apiKey = 'demo-api-key';
  const messagingSenderId = '000000000000';
  if (kIsWeb) {
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: '1:000000000000:web:0000000000000000000000',
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: '$projectId.firebaseapp.com',
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: '1:000000000000:ios:0000000000000000000000',
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      iosBundleId: 'com.gazuacup.janggigo',
    );
  }
  return const FirebaseOptions(
    apiKey: apiKey,
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
  );
}

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

  static bool isValidFormat(String nickname) =>
      nickname.length >= minLength && nickname.length <= maxLength && pattern.hasMatch(nickname);
}

/// 닉네임을 입력하다 멈춘 뒤 서버에 쓸 수 있는지 물어볼 때까지 기다리는 시간.
const nicknameCheckDelay = Duration(milliseconds: 400);
