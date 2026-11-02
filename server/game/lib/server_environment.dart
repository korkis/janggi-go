import 'dart:io';

/// 대국 서버가 붙는 Firebase 환경.
enum ServerMode {
  /// 개발 PC. Firebase Emulator Suite에만 붙는다(`docs/dev_rules.md`의 개발 환경).
  emulator,

  /// Cloud Run 운영 서버.
  production,
}

/// 실행 환경에서 정해지는 값. 대국 규칙 값은 여기 두지 않고 `config.dart`에 둔다.
///
/// 환경 변수는 `server/game/README.md`의 "환경 변수"에 정리한다.
class ServerEnvironment {
  final ServerMode mode;
  final String projectId;

  /// HTTP 서버가 듣는 포트.
  final int port;

  /// Firestore REST API의 기준 주소. 이 뒤에 `/v1/projects/...`가 붙는다.
  final Uri firestoreBaseUri;

  /// Realtime Database 인스턴스 주소. 에뮬레이터면 `ns` 쿼리로 인스턴스를 고른다.
  final Uri rtdbBaseUri;

  /// Cloud Tasks 설정. 에뮬레이터에서는 null이고 같은 프로세스의 타이머가 예약 작업을 부른다.
  final CloudTasksEnvironment? cloudTasks;

  const ServerEnvironment({
    required this.mode,
    required this.projectId,
    required this.port,
    required this.firestoreBaseUri,
    required this.rtdbBaseUri,
    required this.cloudTasks,
  });

  /// [environment]의 환경 변수로 만든다. 값이 빠졌거나 잘못됐으면 [StateError]를 던진다.
  ///
  /// `GAME_ENV=production`일 때만 운영 Firebase에 붙는다. 그 밖에는 에뮬레이터에 붙으며,
  /// Cloud Run(`K_SERVICE`가 있는 곳)에서 에뮬레이터 모드로 켜지면 서명 없는 토큰을 받게 되므로 시작하지 않는다.
  factory ServerEnvironment.fromEnvironment(Map<String, String> environment) {
    final modeName = environment['GAME_ENV'] ?? ServerMode.emulator.name;
    final mode = ServerMode.values.asNameMap()[modeName];
    if (mode == null) {
      throw StateError('GAME_ENV는 ${ServerMode.values.map((m) => m.name).join(', ')} 중 하나여야 합니다: $modeName');
    }
    switch (mode) {
      case ServerMode.emulator:
        if (environment.containsKey('K_SERVICE')) {
          throw StateError('Cloud Run에서는 GAME_ENV=production이 필요합니다');
        }
        return _emulator(environment);
      case ServerMode.production:
        return _production(environment);
    }
  }

  static ServerEnvironment _emulator(Map<String, String> environment) {
    // firebase emulators:exec가 넣어 주는 변수를 먼저 쓰고, 없으면 server/firebase.json의 포트를 쓴다.
    final projectId = environment['GCLOUD_PROJECT'] ?? emulatorProjectId;
    if (!projectId.startsWith('demo-')) {
      // demo 프로젝트가 아니면 에뮬레이터가 없는 서비스 호출이 운영 자원으로 갈 수 있다.
      throw StateError('에뮬레이터 모드의 프로젝트는 demo-로 시작해야 합니다: $projectId');
    }
    final firestoreHost = environment['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:${EmulatorPorts.firestore}';
    final rtdbHost = environment['FIREBASE_DATABASE_EMULATOR_HOST'] ?? '127.0.0.1:${EmulatorPorts.database}';
    return ServerEnvironment(
      mode: ServerMode.emulator,
      projectId: projectId,
      port: _parsePort(environment['PORT'] ?? '$emulatorServerPort'),
      firestoreBaseUri: Uri.parse('http://$firestoreHost'),
      rtdbBaseUri: Uri.parse('http://$rtdbHost/?ns=$rtdbInstance'),
      cloudTasks: null,
    );
  }

  static ServerEnvironment _production(Map<String, String> environment) {
    final port = environment['PORT'];
    if (port == null) {
      throw StateError('PORT가 없습니다. Cloud Run이 넣어 줍니다');
    }
    final serverUrl = _require(environment, 'GAME_SERVER_URL');
    return ServerEnvironment(
      mode: ServerMode.production,
      projectId: productionProjectId,
      port: _parsePort(port),
      firestoreBaseUri: Uri.parse('https://firestore.googleapis.com'),
      rtdbBaseUri: Uri.parse('https://$rtdbInstance.$rtdbRegion.firebasedatabase.app'),
      cloudTasks: CloudTasksEnvironment(
        location: region,
        queue: _require(environment, 'TASKS_QUEUE'),
        serverUrl: Uri.parse(serverUrl),
        serviceAccountEmail: _require(environment, 'TASKS_SERVICE_ACCOUNT'),
      ),
    );
  }

  static String _require(Map<String, String> environment, String name) {
    final value = environment[name];
    if (value == null || value.isEmpty) {
      throw StateError('$name가 없습니다');
    }
    return value;
  }

  static int _parsePort(String value) {
    final port = int.tryParse(value);
    if (port == null || port <= 0 || port > 65535) {
      throw StateError('PORT가 올바르지 않습니다: $value');
    }
    return port;
  }

  /// 운영 Firebase 프로젝트(`server/.firebaserc`).
  static const productionProjectId = 'janggi-go';

  /// 에뮬레이터용 demo 프로젝트. `server/functions`의 `npm run emulators`와 같다.
  static const emulatorProjectId = 'demo-janggi-go';

  /// Cloud Run과 Cloud Tasks 리전(서울).
  static const region = 'asia-northeast3';

  /// Realtime Database 인스턴스(`server/firebase.json`). 에뮬레이터도 같은 이름을 써서 보안 규칙이 적용된 인스턴스에 쓴다.
  static const rtdbInstance = 'janggi-go-default-rtdb';

  /// Realtime Database 리전(싱가포르).
  static const rtdbRegion = 'asia-southeast1';

  /// 개발 PC에서 대국 서버가 듣는 포트. Firestore 에뮬레이터(8080)와 겹치지 않게 정했다.
  static const emulatorServerPort = 8090;

  /// 지금 프로세스의 환경 변수로 만든다.
  static ServerEnvironment fromPlatform() => ServerEnvironment.fromEnvironment(Platform.environment);
}

/// 에뮬레이터 포트. `server/firebase.json`의 emulators와 같다.
abstract final class EmulatorPorts {
  static const auth = 9099;
  static const firestore = 8080;
  static const database = 9000;
}

/// Cloud Tasks로 예약 작업을 만들 때 쓰는 값.
class CloudTasksEnvironment {
  final String location;
  final String queue;

  /// 대국 서버의 Cloud Run 주소. 예약 작업은 `{serverUrl}/tasks/...`를 부르고, OIDC 토큰의 audience도 이 값이다.
  final Uri serverUrl;

  /// 예약 작업의 OIDC 토큰을 만드는 서비스 계정. `/tasks/...`는 이 계정의 토큰만 받는다.
  final String serviceAccountEmail;

  const CloudTasksEnvironment({
    required this.location,
    required this.queue,
    required this.serverUrl,
    required this.serviceAccountEmail,
  });
}
