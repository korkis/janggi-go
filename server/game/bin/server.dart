import 'dart:async';
import 'dart:io';

import 'package:janggigo_game/game_server.dart';
import 'package:janggigo_game/logging.dart';
import 'package:janggigo_game/server_environment.dart';

/// 대국 서버를 켠다. 실행 방법과 환경 변수는 `server/game/README.md`에 있다.
Future<void> main() async {
  final environment = ServerEnvironment.fromPlatform();
  final logger = GameLogger(
    // Cloud Run은 JSON 한 줄을 Cloud Logging 항목으로 읽는다.
    format: environment.mode == ServerMode.production ? LogFormat.json : LogFormat.text,
    minSeverity: LogSeverity.debug,
  );
  final server = GameServer.create(environment: environment, logger: logger);
  await server.serve();

  // Cloud Run은 인스턴스를 내릴 때 SIGTERM을 보낸다. Windows는 SIGTERM을 들을 수 없다.
  final signals = [ProcessSignal.sigint, if (!Platform.isWindows) ProcessSignal.sigterm];
  late final List<StreamSubscription<ProcessSignal>> subscriptions;
  subscriptions = [
    for (final signal in signals)
      signal.watch().listen((received) async {
        logger.info('game server 종료', {'signal': received.toString()});
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await server.close();
      }),
  ];
}
