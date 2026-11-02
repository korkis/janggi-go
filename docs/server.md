# 서버 설계

온라인 대국(로드맵 2단계)의 서버 구성, 대국 서버 API, 앱과 서버가 주고받는 흐름, 설정, 구현 순서다. 데이터 구조와 보안 규칙은 [database.md](./database.md)에 있다.

각 항목은 **확정**, **초안**, **제안**, **미정**으로 표시한다. 사용자와 정한 항목은 확정이고, 나머지 기술 설계는 구현하면서 확정한다.

## 구성 — 초안

```mermaid
flowchart LR
    App[앱<br>Flutter]
    Game[대국 서버<br>Cloud Run Dart<br>서울]
    Tasks[Cloud Tasks<br>서울]
    Fn[Functions<br>TypeScript<br>서울]
    FS[(Firestore<br>서울)]
    RT[(Realtime Database<br>싱가포르)]
    Admin[Admin 웹]

    App -->|대국 API| Game
    App -->|Callable| Fn
    App -->|실시간 듣기,<br>접속 상태 쓰기| RT
    App -->|읽기, 차단 쓰기| FS
    Game --> FS
    Game --> RT
    Game -->|시간 예약| Tasks
    Tasks -->|예약 작업| Game
    Fn --> FS
    Fn --> RT
    Admin -->|Callable| Fn
```

| 구성 | 맡는 일 |
|---|---|
| 대국 서버 (`server/game`) | 대국 상태와 매칭에 관한 모든 쓰기. 빠른 대국, 방, 신청, 접속자 목록, 상차림, 수, 시계, 접속 끊김, 결과, 레이팅, 다시 두기 |
| Functions (`server/functions`) | 대국 밖의 서버 기능. 프로필과 닉네임, 채팅 검사와 저장, 신고, 제재, Admin 웹 Callable, 보관 기간 정리 |
| 앱이 직접 쓰는 것 | 접속 상태(`connections`), 관전자 표시(`spectators`), 차단 목록, 신청 받기 설정 |
| Cloud Tasks | 대국 서버가 정한 시각에 대국 서버를 다시 부른다. 시간패, 상차림 마감, 접속 끊김 마감, 매칭 범위 넓히기, 신청 응답 마감 |

### 대국 서버와 Functions의 경계 — 초안

- 대국 상태(수, 시계, 결과, 급수)와 그 대국을 만드는 매칭 상태(대기열, 방, 신청, 사용자 활동)는 대국 서버만 쓴다. 한 사람이 대기열·방·대국·신청 중 하나에만 있도록 한 곳에서 관리하기 위해서다.
- Functions는 대국 상태를 쓰지 않는다. 채팅 권한을 확인할 때 대국 정보를 읽기만 한다.
- `users/{uid}`는 둘이 함께 쓴다. 닉네임은 Functions, 급수와 전적은 대국 서버가 쓴다. 같은 필드를 둘이 쓰지 않는다.
- 제재 확인: 대국 서버는 대기열·방·신청을 시작할 때 이용 정지와 영구 정지를 확인하고, Functions는 채팅을 받을 때 채팅 제한까지 확인한다.

## 대국 서버 실행 방식 — 확정

- 대국 서버는 요청이 올 때만 실행한다. 진행 중 대국, 대기열, 방, 신청은 메모리에 두지 않고 모두 Firestore와 RTDB에 둔다. 요청마다 DB에서 읽어 판정하고 다시 쓴다.
- 요청 없이 시간이 지나서 일어나는 일(시간패, 상차림 마감, 접속 끊김 마감, 매칭 범위 넓히기, 신청 응답 마감)은 Cloud Tasks로 그 시각에 대국 서버를 다시 부르게 예약한다.
- 사용자가 늘면 Cloud Run이 인스턴스를 늘린다. 최소 인스턴스는 개발과 출시 모두 0으로 둔다. 꺼져 있다가 첫 요청에 켜지는 지연(1초 안팎)이 생기므로, 사용자가 어느 정도 생기면 운영자가 판단해 1로 올린다. 코드는 바꾸지 않고 배포 설정만 바꾼다: `gcloud run services update game --region asia-northeast3 --min-instances 1`.
- 리전은 `asia-northeast3`(서울)이다.

### 동시에 들어온 요청 — 초안

- 한 대국 안의 변경은 RTDB `games_active/{gameId}` 노드 전체를 ETag 조건부 쓰기로 바꾼다. 다른 요청이 먼저 썼으면 다시 읽고 다시 판정한다.
- 여러 사람이 걸린 매칭(대기열, 방 입장, 신청 수락, 다시 두기)은 Firestore 트랜잭션으로 `player_states`, `quick_queue`, `rooms`, `challenges`를 한꺼번에 바꾼다.
- 대국을 만들 때는 RTDB에 대국을 먼저 쓰고 Firestore 트랜잭션으로 두 사람을 그 대국에 묶는다. 트랜잭션이 실패하면 만든 대국을 지운다. 중간에 서버가 멈춰 어느 쪽에도 묶이지 않은 대국은 정리 작업이 지운다.
- RTDB의 파생 데이터(`spectate_list`, `online_users`)는 대국 상태를 쓴 뒤에 따라 쓴다.

### 호출 방식 — 초안

- 앱은 Functions Callable과 같은 프로토콜로 대국 서버를 부른다. Flutter의 `httpsCallableFromUrl`을 그대로 쓰기 위해서다.
  - 요청: `POST {서버 주소}/{API 이름}`, 본문 `{"data": {...}}`, `Authorization: Bearer <Firebase ID token>`.
  - 성공: `{"result": {...}}`.
  - 실패: `{"error": {"status": "FAILED_PRECONDITION", "message": "...", "details": {"code": "<오류 코드>"}}}`.
- 대국 서버는 Firebase ID token을 직접 검증한다(Google 공개 키, `aud`·`iss`가 프로젝트와 같은지). 에뮬레이터에서는 에뮬레이터 토큰을 받는다.
- 예약 작업 경로(`/tasks/...`)는 Cloud Tasks 서비스 계정의 OIDC 토큰만 받는다.
- 요청 파라미터는 API별 `validateParams()`에서 검증한다([dev_rules.md](./dev_rules.md)의 Dart 대국 서버 규칙).
- 앱은 오류 코드로 다국어 메시지를 고르고, 모르는 코드는 그 작업의 기본 오류 메시지로 보여준다.

| 오류 코드 | 뜻 |
|---|---|
| `profileRequired` | 닉네임을 아직 정하지 않았다 |
| `sanctioned` | 이용 정지 또는 영구 정지 중이다 |
| `busy` | 이미 대기열, 방, 대국, 신청 중 하나에 있다 |
| `notFound` | 방, 대국, 신청이 없다 |
| `roomFull` | 방에 자리가 없다 |
| `roomClosed` | 방이 닫혔다 |
| `kicked` | 이 방에서 내보내졌다 |
| `rankOutOfRange` | 방의 급수 범위 밖이다 |
| `notHost` | 방장만 할 수 있다 |
| `notPlayer` | 이 대국의 대국자가 아니다 |
| `notYourTurn` | 내 차례가 아니다 |
| `illegalMove` | 둘 수 없는 수다 |
| `moveConflict` | 수 번호가 서버와 다르다. 앱은 서버 상태로 다시 맞춘다 |
| `gameOver` | 이미 끝난 대국이다 |
| `challengeLimited` | 이 상대에게 지금은 신청할 수 없다(연속 거절 제한) |
| `targetUnavailable` | 상대가 접속해 있지 않거나, 대국 중이거나, 신청을 받지 않거나, 다른 신청을 받고 있다 |
| `rematchUnavailable` | 상대가 나갔거나 다시 두기 횟수에 닿았다 |
| `extensionLimit` | 시간 연장을 더 쓸 수 없다 |

## 대국 서버 API — 초안

모든 API는 로그인과 닉네임(`users/{uid}`)이 있어야 한다.

### 접속자

| API | 파라미터 | 하는 일 |
|---|---|---|
| `enterLobby` | 없음 | `online_users/{uid}`에 닉네임, 급수, 상태, 신청 받기를 쓴다. 앱이 로그인 상태로 RTDB에 연결될 때마다 부른다 |

### 빠른 대국

| API | 파라미터 | 하는 일 |
|---|---|---|
| `joinQuickQueue` | 없음 | 대기열에 넣고 바로 한 번 매칭을 시도한다. 상대가 없으면 범위 넓히기 작업을 예약한다. 결과 `gameId`(찾았으면 새 대국, 아니면 null). 이미 대기열에 있으면 기다린 시간을 그대로 두고 다시 찾기만 한다. 이용 정지 중이면 `sanctioned`, 방·대국·신청 중이면 `busy` |
| `leaveQuickQueue` | 없음 | 대기열에서 뺀다. 이미 매칭됐으면 `busy`. 대기열에 없으면 그대로 성공한다 |

### 방

| API | 파라미터 | 하는 일 |
|---|---|---|
| `createRoom` | `hostSide`, `handicap?`, `listed`, `rankRange?` | 방을 만들고 `roomId`를 돌려준다 |
| `joinRoom` | `roomId` | 빈자리에 앉는다. 링크, 방 목록 모두 이것을 쓴다 |
| `leaveRoom` | `roomId` | 방에서 나간다. 방장이면 방을 닫는다 |
| `kickGuest` | `roomId` | 방장이 상대를 내보낸다. 내보낸 사람은 방이 닫힐 때까지 못 들어온다 |
| `startRoomGame` | `roomId` | 방장이 대국을 시작한다. `gameId`를 돌려준다 |

### 신청

| API | 파라미터 | 하는 일 |
|---|---|---|
| `sendChallenge` | `toUid`, `senderSide?`, `handicap?`, `roomId?` | 신청을 만들고 응답 마감 작업을 예약한다. `roomId`가 있으면 방 조건을 쓴다 |
| `cancelChallenge` | `challengeId` | 보낸 사람이 취소한다 |
| `respondChallenge` | `challengeId`, `accepted` | 받은 사람이 수락하거나 거절한다. 수락하면 대국을 만들거나(`roomId` 없음) 방에 앉힌다 |

### 대국

| API | 파라미터 | 하는 일 |
|---|---|---|
| `setFormation` | `gameId`, `formation`, `confirmed` | 상차림을 골라 둔다(`confirmed: false`, `player_states.setupDraft`에 저장) 또는 확정한다 |
| `playMove` | `gameId`, `moveIndex`, `move` | 수 또는 `pass`를 둔다. `moveIndex`는 이 수가 몇 번째 수인지(0부터)다. 같은 수를 다시 보내면 성공으로 본다 |
| `resign` | `gameId` | 기권한다 |
| `useTimeExtension` | `gameId` | 시간 연장권을 쓴다. 연장권 보유는 3단계에서 정하므로 2단계에는 만들지 않는다 |
| `checkGame` | `gameId` | 대국 판정을 다시 보게 한다(아래 "판정 다시 보기"). 대국자만 부를 수 있고, 끝난 대국이면 아무것도 하지 않고 성공한다. 앱이 부르는 때는 아래 "접속 끊김" |
| `requestRematch` | `gameId` | 다시 두기를 누른다. 두 사람이 모두 누르면 새 대국을 만든다. 결과 `gameId`(새 대국이 정해졌으면 그 ID, 상대를 기다리면 null). 끝나지 않은 대국, 상대가 나갔거나 앱에 없을 때, 횟수에 닿았을 때는 `rematchUnavailable` |
| `leaveResult` | `gameId` | 결과 화면을 나간다. 기다리던 다시 두기를 취소하고, 방 대국이면 방 대기실로 돌린다. 대국이 이미 지워졌으면 그대로 성공한다 |

### 예약 작업 (Cloud Tasks 전용)

| 경로 | 예약하는 때 | 하는 일 |
|---|---|---|
| `/tasks/evaluateGame` | 상차림 마감, 시간패 시각, 접속 끊김 마감 | 판정 다시 보기 |
| `/tasks/retryQuickMatch` | 대기열에 들어간 뒤 10초마다 | 넓어진 범위로 다시 매칭. 앱 연결이 모두 끊겼으면 대기열에서 뺀다 |
| `/tasks/expireChallenge` | 신청 응답 마감 | 응답이 없으면 `expired`로 바꾸고 제한 횟수를 센다 |
| `/tasks/finalizeGame` | 대국이 끝날 때 | 기보 저장, 레이팅·전적 반영. 실패하면 Cloud Tasks가 다시 부른다 |
| `/tasks/cleanupGame` | 대국을 만들 때, 끝날 때 | 묶이지 않은 대국과 끝난 지 오래된 대국을 RTDB에서 지운다 |
| `/tasks/checkRoom` | 방이 열려 있는 동안 1분마다 | 방장 연결이 끊긴 지 오래면 방을 닫고, 상대가 끊겼으면 자리를 비운다 |

예약 시각은 정확하지 않을 수 있다. 판정은 항상 서버가 받은 시각이 아니라 기록된 시각(마감 시각)으로 계산하므로 작업이 늦게 돌아도 결과는 같다.

## 대국 진행 — 초안

### 판정 다시 보기

`evaluateGame`(예약 작업)과 `checkGame`(앱), 그리고 모든 대국 API는 처음에 같은 판정을 한다.

1. 지금 시각까지 지나간 사건을 시각 순서대로 찾는다. 상차림 마감, 시간패 시각, 각 쪽의 접속 끊김 마감.
2. 가장 이른 사건부터 적용한다. 예를 들어 한의 상차림 마감이 지났으면 `setupDraft` 또는 기본값(마상마상)으로 확정하고, 초의 상차림 시간은 지금이 아니라 한의 마감 시각부터 센다.
3. 대국이 끝나는 사건을 만나면 거기서 멈춘다.
4. 다음 사건 시각에 `evaluateGame`을 예약한다.

### 대국 만들기와 상차림

- 대국을 만들 때 `meta`에 대국자, 시간 규칙, `disconnectLimitMs`, 접장기를 고정한다.
- 상차림은 상대 찾음 화면 뒤에 시작한다. `setup.startsAt` = 만든 시각 + 상대 찾음 표시 시간이다. 방 대국과 신청 대국에도 같은 값을 쓴다.
- 한이 먼저 고르고 초는 한의 상차림이 확정된 뒤 고른다([rules.md](./game/rules.md), [time.md](./game/time.md)). 확정된 한의 상차림만 `state.setup.han`에 쓴다. 골라 두기만 한 것은 `player_states.setupDraft`에 둬서 상대에게 보이지 않게 한다.
- 양쪽이 확정되면 `janggi_core`의 `createInitialPosition`으로 `initialFen`을 만들고 초의 차례를 시작한다.

### 수

1. 차례, `moveIndex`, 대국 진행 여부를 확인한다.
2. `initialFen`과 `moves`로 `Game.replay`를 해서 `Game.isLegal`로 검사한다. 수 판정은 `janggi_core`만 쓴다.
3. 받은 시각으로 둔 쪽의 시계를 계산한다(아래 "시계"). 시간이 이미 다 지났으면 수를 받지 않고 시간패로 끝낸다.
4. 수를 붙이고 차례와 `turnStartedAt`을 바꾼다. `Game.play` 결과가 끝난 대국이면(외통, 점수 판정) 결과를 쓴다.
5. `spectate_list`의 국면, 수, 관전자 수를 갱신한다.

앱은 수를 보내자마자 자기 판에 먼저 보여주고, 서버가 거절하면 서버 상태로 되돌린다.

### 시계

[time.md](./game/time.md)를 서버가 계산한다. 앱은 같은 식으로 표시만 한다. 앱은 RTDB `.info/serverTimeOffset`으로 서버 시각을 어림한다.

- 차례가 시작될 때 둘 쪽의 `baseMs`(남은 기본 시간)와 `periods`(남은 초읽기 횟수)를 기록한다.
- 그 차례에 쓴 시간 `spent` = 수를 받은 시각 − `turnStartedAt`.
- `spent`가 `baseMs` 이하면 `baseMs`에서 뺀다.
- 넘으면 `over` = `spent` − `baseMs`, `baseMs` = 0, 초읽기 횟수를 `over ÷ periodMs`의 몫만큼 줄인다. 30초 안에 두면 줄지 않는다.
- 시간패 시각 = `turnStartedAt` + `baseMs` + (`periods` + 1) × `periodMs`. "초읽기 3회를 모두 쓴 뒤 30초 안에 두지 못하면 시간패"를 그대로 계산한 값이다.
- 한수쉼도 한 수로 시계를 넘긴다.
- 네트워크 지연을 보정하지 않는다. 서버가 받은 시각이 기준이다.

### 접속 끊김

[rules.md](./game/rules.md)의 접속 끊김을 서버가 판정한다.

- 앱은 로그인한 동안 RTDB `connections/{uid}/{connectionId}`에 접속 상태를 쓴다(`ConnectionManager`).
  - RTDB에 연결될 때마다(`.info/connected`) 지난 연결 키를 지우고 새 연결에 `online: true`, `foreground`, `activeSince`·`lastSeenAt`(서버 시각)을 쓴 뒤 `onDisconnect`로 `online: false`를 걸어 둔다. 보안 규칙이 연결의 필드를 모두 요구하므로 연결을 쓴 뒤에 건다.
  - 진행 중 대국(`player_states.gameId`, 상차림 포함)이 있는 동안 `heartbeatSeconds`마다 `lastSeenAt`을 갱신한다. 대국이 생기면 바로 한 번 쓴다.
  - 다른 앱으로 넘어가면(앱 생명주기 `hidden`, `paused`) `foreground: false`와 `lastSeenAt`을 쓴다. 돌아오면(`resumed`, `inactive`) `foreground: true`와 `activeSince`를 쓴다.
- 서버는 대국자의 연결 중 `online`이고 `foreground`이며 `lastSeenAt`이 `presenceStaleSeconds` 안인 것이 하나라도 있으면 연결된 것으로 본다.
- 판정 다시 보기마다 두 대국자의 `connections`를 읽어 `state.disconnect`를 그 시각에 맞춘다.
  - 끊긴 시각은 그 사람의 가장 최근 `lastSeenAt`이다. 네트워크가 갑자기 끊겨 RTDB가 늦게 알아채도 마지막으로 살아 있던 시각부터 센다. 대국을 만든 시각보다 앞이면(연결 기록이 없을 때 포함) 만든 시각으로 한다.
  - 끊긴 시각보다 뒤의 `activeSince`가 있는 연결이 있으면 그중 가장 이른 `activeSince`에 돌아온 것으로 보고 끊긴 시간(`activeSince` − 끊긴 시각)을 `usedMs`에 더한다. 그 연결이 다시 끊겨 있으면(서버가 돌아온 것을 보지 못한 사이 다시 나간 경우) 가장 최근 `lastSeenAt`부터 다시 센다.
  - 연결되어 있는데 끊긴 시각보다 뒤의 `activeSince`가 없으면(네트워크가 잠깐 멈췄다가 RTDB 연결이 바뀌지 않고 이어진 경우) 끊긴 시간을 더하지 않고 끊김을 지운다. 이렇게 되지 않도록 앱은 서버가 자기를 끊긴 것으로 기록했는데 자기는 연결되어 있으면 `activeSince`를 새로 쓰고 `checkGame`을 부른다.
  - 돌아오기 전에 `usedMs` + 끊긴 시간이 `disconnectLimitMs`에 닿았으면 돌아왔어도 그 시각에 진다.
- `usedMs` + 지금 끊겨 있는 시간이 `disconnectLimitMs`에 닿으면 끊긴 쪽이 진다. 그 시각에 `evaluateGame`을 예약한다.
- 서버는 끊김을 스스로 알 수 없으므로 판정을 다시 보는 계기가 필요하다. 앱은 대국 화면과 상차림 화면에서 다음을 보면 `checkGame`을 부른다. 같은 서버 상태(`state.version`)에서는 같은 까닭으로 한 번만 부른다.
  - 상대의 `connections`에 `online`이고 `foreground`인 연결이 없는데 서버 기록에 상대 끊김이 없을 때.
  - 상대가 돌아왔는데(`online`이고 `foreground`인 연결이 있다) 서버 기록에 상대 끊김이 남아 있을 때.
  - 서버 기록에 내 끊김이 있는데 나는 연결되어 있을 때(먼저 `activeSince`를 새로 쓴다).
  - 상대 시계가 0이 되었을 때(차례마다 한 번).
  - 진행 중 대국이 있는 동안 RTDB에 다시 연결되거나 다른 앱에서 돌아왔을 때(돌아온 앱, 화면과 상관없이).
  - 둘 다 끊기면 시간패 예약 작업이 판정한다. 그때 접속 끊김 마감과 시간패 중 먼저 온 것으로 끝낸다. 같은 시각이면 시간패다.
- 상대의 수, 상차림 같은 다른 대국 API도 처음에 같은 판정을 하므로 그때도 끊김을 기록한다.
- 누가 `checkGame`을 부르든 서버는 RTDB의 접속 기록만 보고 판정하므로 부른 사람이 결과를 바꿀 수 없다.
- 상차림 시간에도 끊긴 시간을 센다. 끊긴 동안에도 시계는 흐른다.
- 앱의 표시는 서버 기록(`state.disconnect`)과 대국을 만들 때 정한 `meta.disconnectLimitMs`로 한다. 상대 끊김은 상대 정보 줄에 남은 허용 시간을, 내 기기의 RTDB 연결이 끊기면 판 위에 "다시 연결하는 중"을 보여준다([screens.md](./screens.md)의 대국 화면).

### 기권

- 대국 중(상차림 포함) 언제든 할 수 있다. 상차림 중 기권도 패로 기록한다.

### 결과와 레이팅

1. 결과(`result`, `endedAt`)를 RTDB에 쓰고 `phase`를 `finished`로 바꾼다. `spectate_list`에서 지운다.
2. `finalizeGame`을 예약하고 바로 한 번 실행한다. Firestore 트랜잭션 하나로 다음을 한다. `games_archived/{gameId}`가 이미 있으면 아무것도 하지 않는다(한 번만 반영).
   - `games_archived/{gameId}` 만들기.
   - `users/{uid}.stats` 갱신.
   - 급수 대국이면 `ratings` 갱신, `users.rankLevel`, `users_private.rankProgress`·`winsToNextRank`, `player_states.lastRankChange` 쓰기.
   - `player_states.gameId`를 비우고 `lastGameId`를 쓴다.
3. `online_users`의 상태를 `waiting`으로 돌린다.

레이팅은 [rank.md](./game/rank.md)의 Elo를 쓴다.

- 기대 승률 E = 1 / (1 + 10^((상대 레이팅 − 내 레이팅) / 400)).
- 변동 = K × (결과 − E). 결과는 이기면 1, 지면 0이다. K는 이 대국 전의 내 `ratedGames`로 고른다. 레이팅은 소수 그대로 저장한다.
- 급수는 바뀐 레이팅이 들어가는 구간으로 바로 정한다.
- 진행 막대(`rankProgress`) = (레이팅 − 지금 급수 구간의 시작) ÷ 50을 0~1로 자른 값. 18급 구간은 1000부터 센다(1000 아래면 0). 9단은 다음 급수가 없으므로 1이다.
- 어림 승수 = (다음 급수 시작 레이팅 − 지금 레이팅) ÷ (K × 0.5)를 올림한 값이고 1보다 작지 않다. K는 다음 판의 K다. 비슷한 레이팅의 상대를 이기면 K의 절반쯤 오른다는 어림이다. 9단이면 null.
- 급수 변동(`lastRankChange`)의 "전" 값은 이 대국 전 레이팅으로 계산한다. `ratings` 문서가 없으면 처음 레이팅(1000)이다.
- 급수 대국은 빠른 대국(다시 두기 포함)이고 접장기가 아닌 대국이다. 대국을 만들 때 `meta.rated`에 정한다.
- `users_private` 문서가 없으면(Functions가 프로필과 함께 만드는 문서라 정상이면 없다) 급수 진행만 쓰지 않고 나머지는 반영한다. 대국 마무리를 막지 않기 위해서다.

### 다시 두기

[matching.md](./game/matching.md)의 다시 두기를 따른다.

- `requestRematch`는 `rematch.{side}`를 true로 쓴다. 두 쪽이 모두 true가 되는 쓰기에서 새 대국 ID를 정해 `rematch.gameId`에 함께 쓰고, 그 쓰기를 한 요청만 같은 조건으로 새 대국을 만든다. 두 요청이 동시에 와도 RTDB 조건부 쓰기로 한 요청만 새 ID를 쓴다. 늦게 온 요청은 정해진 ID를 돌려받는다.
- 앱은 `rematch.gameId`가 생기고 내 `player_states.gameId`가 그 값이 되면(새 대국이 RTDB에 생기고 두 사람이 묶인 뒤) 상차림으로 간다.
- 새 대국을 만들지 못하면(예: 그새 한 사람이 다른 대국에 묶였다) `rematch.gameId`를 지우고 `cancelled`를 true로 둔다.
- 새 대국을 만들기 전에 앞 대국의 `finalizeGame`을 한 번 더 불러(이미 했으면 아무것도 하지 않는다) 레이팅을 반영하고 두 사람을 푼다. 새 대국의 닉네임과 급수는 그 뒤의 `users` 값이다.
- 초와 한은 바꾼다. 접장기면 떼는 쪽이 계속 한이다.
- 새 대국의 `rematchCount`는 앞 대국 + 1이다. 빠른 대국은 앞 대국의 `rematchCount`가 `quickRematchLimit`에 닿았으면 받지 않는다. 그런 대국은 만들 때부터 `rematch.blocked`를 true로 두어 결과 화면이 처음부터 버튼을 끈다. 방 대국과 신청 대국은 횟수를 세기만 하고 막지 않는다.
- `leaveResult`를 받으면 `rematch.cancelled`를 true로 둔다. 결과 화면에서 앱이 꺼진 경우는 상대가 `requestRematch`를 부를 때 서버가 `connections`로 끊긴 것을 보고 취소로 처리한다. 상대가 먼저 눌렀어도 같다.
  - 이때 연결된 것은 `online`이고 `foreground`인 연결이 있는 것이다. 대국이 끝나면 앱이 `lastSeenAt`을 갱신하지 않으므로 대국 중 판정과 달리 `presenceStaleSeconds`는 보지 않는다.
- 결과 창의 "한 판 더", 복기하기, 홈으로는 모두 `leaveResult`를 부른 뒤 넘어간다. 결과 창을 뒤로 가기로 닫으면 홈으로 간다.

## 매칭 — 초안

### 빠른 대국

[rank.md](./game/rank.md)의 빠른 대국 매칭을 따른다.

- `joinQuickQueue`는 이용 정지를 확인하고, 묶인 대국이 끝났어야 하면 먼저 정리한 뒤, `ratings`의 레이팅으로 `quick_queue/{uid}`와 `player_states.quickQueueJoinedAt`을 한 트랜잭션으로 쓰고 바로 매칭을 시도한다.
- 매칭 시도: 대기열에서 레이팅 차이가 허용 범위 안이면서 가장 가까운 사람을 고른다(같으면 더 오래 기다린 사람). 허용 범위는 두 사람 중 더 오래 기다린 사람의 범위(처음 100점, 10초마다 50점씩, 최대 400점)다(제안).
  - 후보는 내 레이팅 위(같은 값 포함)와 아래에서 가까운 순서로 `quickMatchCandidateLimit`(10)명씩 읽는다. 쿼리는 트랜잭션 밖에서 하고, 고른 상대는 아래 트랜잭션에서 다시 확인한다.
  - 앱을 화면에 띄워 둔 연결(`online`이고 `foreground`)이 없는 후보는 건너뛴다. 다른 앱으로 넘어간 사람과 대국을 시작하지 않기 위해서다.
- 상대가 없으면 다음 10초 시각에 `retryQuickMatch`를 예약한다. 범위가 400점에 닿은 뒤에도 대기열에 있는 동안 계속 예약한다. 나갔거나 매칭됐거나 다시 들어왔으면(기다린 시각이 다르다) 예약 작업은 아무것도 하지 않는다. 앱 연결이 하나도 `online`이 아니면(앱을 껐다) 대기열에서 뺀다.
- 찾으면 RTDB에 대국을 만들고, Firestore 트랜잭션으로 두 사람의 `quick_queue`가 그때 읽은 그대로 남아 있는지 확인한 뒤 지우고, `quickQueueJoinedAt`을 비우고 `player_states.gameId`를 쓴다. 상대가 그새 다른 사람과 묶였으면 대국을 지우고 다시 찾는다(최대 3번). 내가 그새 묶였으면 그만 찾는다.
- 초와 한은 무작위로 정한다. 대국은 `mode: quick`, `rated: true`, `listed: true`다.

### 방

[matching.md](./game/matching.md)의 방 만들기, 링크, 방 유지를 따른다.

- 방장은 만들 때, 상대는 들어올 때 `player_states.roomId`를 쓴다.
- `startRoomGame`으로 만든 대국이 끝나면 방은 `waiting`으로 돌아간다. 두 사람 모두 결과 화면을 나가면 방 대기실로 돌아온다(`roomId`가 남아 있다).
- 진영: `hostSide`가 `random`이면 판마다 무작위로 정한다. 다시 두기로 둔 대국은 다시 두기 규칙대로 바꾼다.
- 공개 방(`listed`)의 대국은 관전 목록에 보이고, 비공개 방의 대국은 보이지 않는다. 비공개 방의 대국은 그 방의 링크로 관전한다.
- `checkRoom` 예약 작업이 방장의 연결을 확인한다. 끊긴 지 `roomAbsentSeconds`가 지나면 방을 닫고, 상대가 그만큼 끊겨 있으면 자리를 비운다.

### 신청

[matching.md](./game/matching.md)의 로비와 신청을 따른다.

- 신청 조건: 받는 사람이 `online_users`에 있고 `waiting`이며, 신청 받기를 켰고, 응답을 기다리는 다른 신청이 없어야 한다. 보내는 사람도 기다리는 신청이 없어야 한다.
- 받는 사람이 보내는 사람을 차단했으면 받는 사람에게 전달하지 않는다. 보내는 사람에게는 응답이 없는 것과 똑같이 보이고 응답 마감에 `expired`가 된다.
- `challenge_limits`의 `blockedUntil`이 지나지 않았으면 `challengeLimited`로 거절한다.
- 거절되거나 응답이 없으면 `failCount`를 1 늘리고, `challengeFailLimit`에 닿으면 `blockedUntil`을 정하고 `failCount`를 0으로 돌린다. 수락되면 0으로 돌린다.
- 받는 사람의 앱은 `player_states.incomingChallengeId`를 보고 어느 화면에서든 수락 팝업을 띄운다.
- 받는 사람이 대기열에 있으면 수락할 때 대기열에서 뺀다.

### 접속자 목록

- 앱이 로그인 상태로 RTDB에 연결되면 `enterLobby`를 부르고, `online_users/{uid}`에 `onDisconnect`로 삭제를 걸어 둔다.
- 앱이 다른 앱으로 넘어가면 자기 항목을 지우고, 돌아오면 다시 `enterLobby`를 부른다.
- 지난 연결의 `onDisconnect`가 늦게 실행돼 항목이 지워질 수 있다. 앱은 연결되어 있는 동안 자기 항목이 없어지면 `enterLobby`를 다시 부른다.
- `configs/app.onlineUsersVisible`이 false여도 항목은 쓴다. 다른 사용자 정보 창의 상태 표시와 신청 조건에 쓰기 때문이다. 앱은 접속자 탭과 방 대기실의 접속자 초대하기만 숨긴다.

### 관전자 수

- 관전 화면을 연 앱은 `spectators/{gameId}/{viewerId}`를 쓰고 `onDisconnect`로 지운다. 로그인하지 않아도 쓴다.
- 대국 서버가 수를 받을 때마다 그 경로의 자식 수를 얕게 읽어(`shallow`) `spectate_list/{gameId}.spectatorCount`에 쓴다. 관전 화면의 "N명 보는 중"도 이 값을 쓴다.

## Functions — 초안

모든 Functions는 `asia-northeast3`에 둔다([dev_rules.md](./dev_rules.md)).

### Callable

| 이름 | 하는 일 |
|---|---|
| `checkNickname` | 닉네임 정하기 화면에서 입력하는 동안 쓸 수 있는지 확인한다. 형식, 중복, 금칙어, 운영진 사칭 단어 |
| `createProfile` | 첫 가입 때 닉네임을 정한다. `nicknames`, `users`(`rankLevel` 1), `users_private`를 한 트랜잭션으로 만든다 |
| `changeNickname` | 닉네임을 바꾼다. 7일 제한, 첫 변경 무료. 엽전을 쓰는 두 번째 변경부터는 3단계에서 붙인다 |
| `sendChatMessage` | `channel`, `gameId?`, `text`를 받아 권한과 채팅 제한을 확인하고 검사한다. 통과하면 `chats_*`와 `chat_checks`에 쓰고, 걸리면 저장하지 않고 `moderation_logs`에 남긴 뒤 거절 사유를 돌려준다 |
| `reportMessage` | `channel`, `gameId?`, `messageId`를 받아 신고된 메시지와 앞뒤 메시지, 검사 결과 사본으로 `reports`를 만든다 |
| `deleteAccount` | 회원 탈퇴. 지울 범위는 [database.md](./database.md)의 미정 |
| Admin Callable | 신고 대기열·상세, 검사 기록, 사용자 조회, 제재 걸기, `configs/app` 바꾸기. 모두 `admin: true` claim을 다시 확인한다 |

### 예약 작업

| 이름 | 주기 | 하는 일 |
|---|---|---|
| `cleanupChats` | 하루 한 번 | 90일 지난 RTDB 채팅을 지운다 |
| `expireSanctions` | 한 시간마다 | 끝난 제재를 `users_private.sanction`에서 지운다 |

Firestore의 보관 기간은 TTL 정책으로 지운다([database.md](./database.md)의 보관과 삭제).

## 앱과 서버의 흐름 — 초안

### 빠른 대국 한 판

```mermaid
sequenceDiagram
    participant A as 앱 A
    participant B as 앱 B
    participant G as 대국 서버
    participant FS as Firestore
    participant RT as RTDB

    A->>G: joinQuickQueue
    G->>FS: quick_queue/A, 상대 없음
    G-->>G: 10초 뒤 retryQuickMatch 예약
    B->>G: joinQuickQueue
    G->>RT: games_active/{id} 만들기
    G->>FS: 트랜잭션: 대기열 지우기, player_states.gameId
    FS-->>A: player_states 변경
    FS-->>B: player_states 변경
    A->>RT: games_active/{id} 듣기
    B->>RT: games_active/{id} 듣기
    Note over A,B: 상대 찾음 화면, 상차림
    A->>G: setFormation (한)
    B->>G: setFormation (초)
    loop 수
        A->>G: playMove
        G->>RT: 수, 시계, 차례
        RT-->>B: 변경
    end
    G->>RT: result, phase finished
    G->>FS: finalizeGame: 기보, 레이팅, 전적
    A->>G: requestRematch 또는 leaveResult
```

1. 앱 A가 `joinQuickQueue`를 부르고 빠른 대국 대기 화면에서 `player_states/{uid}`를 듣는다. "그만 찾기"와 뒤로 가기는 `leaveQuickQueue`. 그새 매칭돼 `busy`면 화면에 남아 대국으로 간다. 홈의 빠른 대국은 진행 중인 대국이 있으면 대기열 대신 그 대국의 상차림 화면을 연다.
2. 매칭되면 `player_states.gameId`가 생긴다(또는 `joinQuickQueue` 결과). 앱은 `games_active/{gameId}`를 듣고 상대 찾음 화면을 `setup.startsAt`까지 보여준 뒤 상차림으로 간다. 대국이 아직 RTDB에 없으면 생길 때까지 기다린다.
3. 상차림에서 누를 때마다 `setFormation(confirmed: false)`, 정하기 버튼은 `confirmed: true`. 마감이 지나면 서버가 확정한다.
4. 대국 중에는 `playMove`, `resign`을 부른다. 상대 시계가 0이 되거나 상대 연결이 끊긴 것을 보면 `checkGame`을 부른다.
5. `state.result`가 생기면 결과 창을 띄운다. 급수 변동은 `player_states.lastRankChange`로 보여준다.
6. 다시 두기는 `requestRematch`, 나가기는 `leaveResult`. "한 판 더"는 `leaveResult` 뒤 `joinQuickQueue`.

### 방과 초대 링크

1. 방장이 `createRoom`을 부르고 방 대기실로 간다. 초대 링크는 `https://<프로젝트>.web.app/r/{roomId}`다.
2. 링크를 누른 사람의 앱(또는 웹)은 로그인과 닉네임을 거친 뒤 `joinRoom`을 부른다. 앱 설치와 열기 흐름은 [matching.md](./game/matching.md)의 링크를 따른다.
3. `joinRoom`이 실패하면 사유를 보여준다. 방이 대국 중이면(`status == playing`) 그 대국의 관전을 권한다.
4. 두 사람은 `rooms/{roomId}`를 듣는다. 방장이 `startRoomGame`을 부르면 두 사람의 `player_states.gameId`가 생기고 상차림으로 간다. 이후는 빠른 대국과 같다.
5. 결과 화면을 나가면(`leaveResult`) 방 대기실로 돌아온다. 상대가 `leaveRoom`하면 빈자리에 같은 링크로 다음 사람이 들어온다.

### 신청

1. 보내는 사람이 `sendChallenge`를 부르고 응답을 기다린다.
2. 받는 사람의 앱은 `player_states.incomingChallengeId`가 생기면 `challenges/{id}`를 읽어 팝업을 띄우고 `expiresAt`까지 남은 시간 막대를 보여준다.
3. `respondChallenge`로 수락하면 두 사람의 `player_states.gameId`가 생긴다(방 초대면 `roomId`). 거절이나 마감이면 보낸 사람의 `challenges/{id}.status`가 바뀐다.

### 재접속

- 앱을 다시 켜거나 네트워크가 돌아오면 앱은 RTDB에 다시 연결하면서 `connections`를 쓰고 `enterLobby`를 부른다.
- `player_states.gameId`가 있으면 홈 맨 위에 "대국으로 돌아가기"를 보여준다. 누르면 상차림 화면으로 열고, 상차림이 끝난 대국이면 상차림 화면이 바로 대국 화면으로 넘긴다. 대국 화면에서 끊겼다 돌아온 경우에는 같은 대국에 바로 다시 붙는다.
- 대국 화면은 `games_active/{gameId}` 전체를 다시 받아 그린다. 기다리던 수가 서버에 없으면(`moveConflict`) 서버 상태를 따른다.
- 돌아온 앱은 `checkGame`을 불러 끊김 시간을 바로 정리하게 한다.
- 이미 끝난 대국이면 결과 창을 보여준다.

## 설정 — 초안

설정을 두는 곳은 [dev_rules.md](./dev_rules.md)의 설정 저장을 따른다.

### `configs/app`

앱, Functions, 대국 서버가 같이 읽는다. 대국 서버도 Functions처럼 짧은 시간 메모리에 캐시한다.

| 필드 | 타입 | 처음 값 | 설명 | 정한 문서 |
|---|---|---|---|---|
| `disconnectLimitSeconds` | number | `30` | 한 대국에서 끊겨 있어도 되는 시간 합계 | [rules.md](./game/rules.md) |
| `quickRematchLimit` | number | `5` | 빠른 대국에서 같은 상대와 연달아 다시 둘 수 있는 횟수 | [matching.md](./game/matching.md) |
| `onlineUsersVisible` | boolean | `false` | 대국실 접속자 탭과 방 대기실의 접속자 초대하기를 보여준다 | [matching.md](./game/matching.md) |
| `autoSanctionEnabled` | boolean | `false` | 자동 제재 사용 | [moderation.md](./moderation.md) |
| `heartbeatSeconds` | number | `5` | 대국 중 앱이 `lastSeenAt`을 갱신하는 주기 | 이 문서 |

### 대국 서버 설정 (`server/game/lib/config.dart`)

알려지면 악용될 수 있거나 운영 중 바꿀 일이 드문 값이다. 바꾸려면 다시 배포한다.

| 설정 | 값 | 정한 문서 |
|---|---|---|
| 기본 시간 | 5분 | [time.md](./game/time.md) |
| 초읽기 | 30초, 3회 | [time.md](./game/time.md) |
| 상차림 시간 | 20초 | [time.md](./game/time.md) |
| 시간 연장 | 1회에 초읽기 2회, 한 대국 2회까지 | [time.md](./game/time.md) |
| 처음 레이팅 | 1000 | [rank.md](./game/rank.md) |
| K 값 | 0~19판 80, 20~99판 40, 100판부터 20 | [rank.md](./game/rank.md) |
| 급수 구간 | 18급 1050 미만부터 50점마다 한 단계, 9단 2300 이상 | [rank.md](./game/rank.md) |
| 빠른 대국 매칭 범위 | 처음 100점, 10초마다 50점, 최대 400점 | [rank.md](./game/rank.md) |
| `quickMatchCandidateLimit` | 10명 | 매칭할 때 내 레이팅 위아래로 각각 읽어 볼 대기열 항목 수. 이 문서 |
| `challengeResponseSeconds` | 20초 | [matching.md](./game/matching.md) |
| `challengeFailLimit` | 3회 | [matching.md](./game/matching.md) |
| `challengeBlockMinutes` | 30분 | [matching.md](./game/matching.md) |
| `matchIntroSeconds` | 3초 (제안) | 상대 찾음 화면 표시 시간. 이 문서 |
| `presenceStaleSeconds` | 15초 | `lastSeenAt`이 이보다 오래되면 끊긴 것으로 본다. `heartbeatSeconds`(5초)로 세 번 갱신하지 못한 때다. 이 문서 |
| `roomAbsentSeconds` | 60초 (제안) | 방장이나 상대가 이만큼 끊기면 방을 닫거나 자리를 비운다. 이 문서 |
| `finishedGameRetentionMinutes` | 10분 (제안) | 끝난 대국을 RTDB에 남겨 두는 시간. 이 문서 |

시간 규칙은 대국을 만들 때 `meta.timeControl`에 복사하므로, 값을 바꿔도 진행 중 대국과 옛 기보는 영향을 받지 않는다.

### Functions 설정 (`server/functions/src/config.ts`)

| 설정 | 값 | 정한 문서 |
|---|---|---|
| Moderation 모델 이름 | 구현 때 정한다 | [moderation.md](./moderation.md) |
| 채팅 보관 | 90일 | [moderation.md](./moderation.md) |
| 검사 기록 보관 | 1년 | [moderation.md](./moderation.md) |
| 닉네임 길이와 글자 | 한글·영문·숫자 2~10자 | [screens.md](./screens.md) |
| 닉네임 변경 제한 | 7일 | [screens.md](./screens.md) |

OpenAI API 키는 Secret Manager에 둔다.

## 개발 환경 — 초안

- 대국 서버는 개발 PC에서 `dart run`으로 띄우고 Firebase Emulator Suite(Auth, Firestore, RTDB, Functions)에 붙는다. 운영 DB에는 연결하지 않는다.
- Cloud Tasks는 에뮬레이터가 없다. 예약 작업은 `TaskScheduler` 인터페이스 뒤에 두고, 개발에서는 같은 프로세스의 타이머가 대국 서버의 `/tasks/...`를 부르는 구현을 쓴다.
- Firestore와 RTDB는 REST API로 다룬다. Dart용 Firebase Admin SDK가 공식으로 없기 때문이다. 쓸 패키지는 구현 첫 단계에서 고른다.
- 앱의 개발 빌드는 대국 서버 주소도 개발 PC를 가리킨다(`app/lib/config.dart`).
- 테스트에서 서로 다른 계정 두 개로 한 판을 끝까지 두는 통합 테스트를 만든다.

## 구현 순서 — 제안

1. **기반 정리.** Firestore 보안 규칙을 기본 거부로 바꾼다(지금 규칙은 2026-11-30까지 모두 열려 있다). RTDB 인스턴스가 `asia-southeast1`에 있는지 확인하고 `firebase.json`에 연결한다. `configs/app` 모델을 앱과 Functions에 만든다.
2. **`janggi_core` 보완.** `GameEndReason.disconnect`와 접속 끊김으로 끝내는 함수를 추가한다.
3. **로그인과 프로필.** 앱 로그인(구글, 애플, 이메일), 닉네임 정하기, Functions `checkNickname`·`createProfile`, `users`·`users_private`·`nicknames` 보안 규칙.
4. **대국 서버 뼈대.** `server/game` Dart 패키지, Callable 프로토콜, ID token 검증, 에뮬레이터 연결, repository, `TaskScheduler`, Dockerfile과 Cloud Run 배포.
5. **한 판 두기.** 개발용 API로 두 계정의 대국을 만들고, 상차림, 수, 시계, 기권, 결과, `finalizeGame`까지. 앱의 온라인 대국 화면과 결과 창.
6. **접속 끊김과 재접속.** `connections`, `checkGame`, 끊김 표시, 대국으로 돌아가기.
7. **빠른 대국.** 대기열, 레이팅 매칭, 레이팅·급수 반영, 다시 두기, 홈 내 카드의 급수.
8. **방과 링크.** 방 만들기, 방 대기실, 방 목록, 내보내기, 방 유지, Hosting의 초대 링크와 App Links·Universal Links.
9. **접속자와 신청.** `online_users`, 접속자 탭, 신청 보내기·받기, 연속 거절 제한, 차단.
10. **관전.** `spectate_list`, `spectators`, 관전 목록, 관전 모드.
11. **채팅과 신고.** `sendChatMessage`(OpenAI Moderation, 금칙어), 세 채팅, 신고, 차단 목록 화면.
12. **기보와 내 정보.** 내 기보 목록, 전적, 나와의 전적, 닉네임 바꾸기.
13. **Admin 웹.** 신고 처리, 검사 기록, 제재, 설정 바꾸기.

5단계까지 끝나면 두 기기에서 실제로 한 판을 둘 수 있다. 이후 단계는 서로 크게 얽히지 않아 순서를 바꿀 수 있다.

## 미정

- 빠른 대국에서 내가 차단한 사람과 매칭되지 않게 할지.
- 시간 연장권을 상대 차례에도 쓸 수 있는지(3단계).
- 프로필 화면의 사용자 신고(채팅 메시지가 아닌 신고)에 무엇을 저장할지([screens.md](./screens.md)의 다른 사용자 정보에 버튼만 있다).
- 채팅 메시지 길이 제한과 연속 전송 제한.
- App Check 사용 여부.
