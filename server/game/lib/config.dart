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

/// 처음 레이팅. 급수 대국을 두지 않은 사용자(`ratings` 문서가 없음)도 이 값으로 본다(`docs/game/rank.md`).
const initialRating = 1000.0;

/// 반영된 대국 수에 따른 Elo K 값(`docs/game/rank.md`의 계산 방식). [ratedGamesUpTo]판까지 [k]를 쓰고, 마지막 값은 그 뒤 모두다.
const ratingKSteps = [(ratedGamesUpTo: 19, k: 80), (ratedGamesUpTo: 99, k: 40), (ratedGamesUpTo: null, k: 20)];

/// 18급 구간의 시작 레이팅. 18급은 이보다 낮아도 18급이고 진행 막대는 0이다.
const rankBaseRating = 1000.0;

/// 급수 한 단계의 레이팅 폭. 18급은 1050 미만, 17급은 1050 이상 1100 미만, 9단은 2300 이상이다(`docs/game/rank.md`).
const rankBandWidth = 50.0;

/// 가장 높은 급수(9단)의 `rankLevel`. 가장 낮은 급수(18급)는 1이다.
const maxRankLevel = 27;

/// 빠른 대국에서 처음 허용하는 레이팅 차이(`docs/game/rank.md`의 빠른 대국 매칭).
const quickMatchInitialRange = 100.0;

/// [quickMatchStepInterval]만큼 기다릴 때마다 넓히는 레이팅 차이.
const quickMatchRangeStep = 50.0;

/// 빠른 대국에서 허용하는 가장 큰 레이팅 차이.
const quickMatchMaxRange = 400.0;

/// 빠른 대국 매칭 범위를 넓히는 간격. 대기열에 있는 동안 이 간격으로 `retryQuickMatch`를 예약한다.
const quickMatchStepInterval = Duration(seconds: 10);

/// 빠른 대국 매칭에서 내 레이팅 위아래로 각각 읽어 볼 대기열 항목 수. 가까운 순서로 읽는다.
const quickMatchCandidateLimit = 10;

/// 방이 열려 있는 동안 `checkRoom`으로 방장과 상대의 연결을 확인하는 간격(`docs/server.md`의 방).
const roomCheckInterval = Duration(seconds: 60);

/// 방장이나 상대의 연결이 이만큼 없으면 방을 닫거나 자리를 비운다. `checkRoom`이 연결 없음을 처음 본 시각부터 센다.
const roomAbsentSeconds = 60;

/// 대국 신청에 응답할 수 있는 시간(`docs/game/matching.md`의 로비와 신청). 지나면 `expireChallenge`가 신청을 `expired`로 바꾼다.
const challengeResponseSeconds = 20;

/// 같은 상대에게 이만큼 연달아 거절되거나 응답을 받지 못하면 [challengeBlockMinutes] 동안 그 상대에게 신청할 수 없다.
const challengeFailLimit = 3;

/// [challengeFailLimit]에 닿았을 때 같은 상대에게 신청할 수 없는 시간.
const challengeBlockMinutes = 30;
