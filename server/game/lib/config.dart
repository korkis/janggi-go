// 대국 서버만 쓰는 설정이다(`docs/dev_rules.md`의 설정 저장). 바꾸려면 다시 배포한다.

import 'models/active_game.dart';

/// `configs/app` 문서를 메모리에 캐시하는 시간. 요청마다 Firestore를 읽지 않기 위해서다. Functions와 같다.
const appConfigCacheDuration = Duration(seconds: 60);

/// 기본 시간(`docs/game/time.md`).
const baseTime = Duration(minutes: 5);

/// 초읽기 한 번의 시간(`docs/game/time.md`).
const byoyomiPeriod = Duration(seconds: 30);

/// 초읽기 횟수(`docs/game/time.md`).
const byoyomiPeriods = 3;

/// 한 진영이 상차림을 고르는 시간(`docs/game/time.md`).
const setupTime = Duration(seconds: 20);

/// 시간 연장 1회에 늘어나는 초읽기 횟수(`docs/game/time.md`). 2단계에는 연장권을 쓰지 않고 `meta.timeControl`에만 기록한다.
const extensionPeriods = 2;

/// 한 대국에서 시간 연장을 쓸 수 있는 횟수(`docs/game/time.md`).
const extensionLimit = 2;

/// 새 대국의 시간 규칙. 대국을 만들 때 `meta.timeControl`에 복사하므로 값을 바꿔도 진행 중 대국은 그대로다.
final defaultTimeControl = TimeControl(
  baseMs: baseTime.inMilliseconds,
  periodMs: byoyomiPeriod.inMilliseconds,
  periods: byoyomiPeriods,
  setupMs: setupTime.inMilliseconds,
  extensionPeriods: extensionPeriods,
  extensionLimit: extensionLimit,
);

/// 상대 찾음 화면을 보여주는 시간. 상차림은 대국을 만든 시각 + 이 시간에 시작한다(`docs/server.md`의 대국 만들기와 상차림).
const matchIntroSeconds = 3;

/// 접속 상태의 `lastSeenAt`이 이보다 오래되면 앱이 연결되어 있다고 써 두었어도 끊긴 것으로 본다(`docs/server.md`의 접속 끊김).
/// 앱은 대국 중 `configs/app.heartbeatSeconds`(5초)마다 갱신하므로 세 번 넘게 갱신하지 못한 경우다.
const presenceStaleSeconds = 15;

/// 끝난 대국을 RTDB `games_active`에 남겨 두는 시간(`docs/server.md`의 대국 서버 설정).
const finishedGameRetentionMinutes = 10;

/// 대국을 만든 뒤 이 시간이 지나도 어느 대국자의 `player_states.gameId`에도 묶이지 않은 대국은 정리 작업이 지운다.
/// 대국을 만드는 요청이 RTDB에 쓴 뒤 Firestore 트랜잭션 전에 멈춘 경우다.
const unboundGameCleanupDelay = Duration(minutes: 1);

/// `finalizeGame`은 대국이 끝날 때 바로 한 번 실행하고, 실패에 대비해 이 시간 뒤에 예약 작업으로 한 번 더 부른다.
/// 바로 실행과 예약 작업이 같은 Firestore 문서를 동시에 바꾸지 않도록 간격을 둔다.
const finalizeGameRetryDelay = Duration(seconds: 30);
