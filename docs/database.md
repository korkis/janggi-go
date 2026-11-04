# 데이터 구조

온라인 대국(로드맵 2단계)이 쓰는 Firestore 컬렉션과 Realtime Database(RTDB) 경로, 각 필드와 보안 규칙 방향이다. 서버 구성과 API는 [server.md](./server.md)에 있다.

이 문서 전체가 **초안**이다. 구현하면서 확정한다. 이름은 [dev_rules.md](./dev_rules.md)의 DB 명명 규칙을 따른다.

## 표기

| 표기 | 뜻 |
|---|---|
| `string`, `number`, `boolean` | 기본 타입 |
| `timestamp` | Firestore Timestamp (UTC) |
| `ms` | RTDB에 저장하는 Unix epoch 밀리초 (UTC) |
| `map`, `array` | 중첩 객체, 배열 |
| `?` | nullable. RTDB는 null을 저장하지 않으므로 필드가 없으면 null이다 |
| enum 이름 | Dart `enum.name`과 같은 문자열 |

쓰기 주체는 다음과 같이 적는다.

| 주체 | 뜻 |
|---|---|
| 앱 | 보안 규칙을 통과한 클라이언트 |
| 대국 서버 | `server/game` (Admin 권한) |
| Functions | `server/functions` (Admin SDK) |
| 서버 전용 | 클라이언트는 읽기·쓰기 모두 막는다 |

## 저장 위치 원칙

| 위치 | 담는 것 | 이유 |
|---|---|---|
| Firestore (서울) | 사용자, 급수, 기보, 설정, 매칭 상태(대기열, 방, 신청, 사용자 활동), 신고·제재 | 대국 서버(서울)와 가까워 여러 문서를 한 트랜잭션으로 바꾸는 매칭에 맞다 |
| RTDB (싱가포르) | 진행 중 대국, 접속 상태, 접속자 목록, 관전, 채팅 | 많은 사람이 실시간으로 읽고, 연결이 끊기면 `onDisconnect`로 바로 표시할 수 있다 |

[plan.md](./plan.md)의 기술 구성(진행 중 대국·접속 상태·관전은 RTDB, 유저 정보·급수·기보·설정은 Firestore)을 그대로 따르고, 문서에 없던 매칭 상태는 Firestore에 둔다.

## 공통 enum

| enum | 값 | 선언 위치 |
|---|---|---|
| `Side` | `cho`, `han` | `janggi_core` |
| `Formation` | `horseElephantHorseElephant` 등 4개 | `janggi_core` |
| `HandicapPiece` | `leftChariot` 등 8개 | `janggi_core` |
| `GameEndReason` | `checkmate`, `resignation`, `timeout`, `disconnect`, `consecutivePasses`, `moveLimit`, `noLegalMoves` | `janggi_core` |
| `GameMode` | `quick`, `room`, `challenge` | 앱, 대국 서버 |
| `GamePhase` | `setup`, `playing`, `finished` | 앱, 대국 서버 |
| `SideChoice` | `cho`, `han`, `random` | 앱, 대국 서버 |
| `HandicapRemover` | `creator`, `opponent` | 앱, 대국 서버. 방장(신청이면 신청한 사람) 기준으로 떼는 쪽 |
| `RoomStatus` | `waiting`, `playing`, `closed` | 앱, 대국 서버 |
| `ChallengeStatus` | `pending`, `accepted`, `declined`, `expired`, `cancelled` | 앱, 대국 서버 |
| `OnlineStatus` | `waiting`, `playing` | 앱, 대국 서버 |
| `ChatChannel` | `lobby`, `game`, `spectator` | 앱, Functions |
| `SanctionType` | `warning`, `chatRestriction`, `suspension`, `permanentBan` | 앱, Functions, 대국 서버, Admin 웹 |
| `ReportStatus` | `pending`, `resolved` | Functions, Admin 웹 |

- `rankLevel`은 급수를 `number` 1~27로 저장한다. 1이 18급, 18이 1급, 19가 1단, 27이 9단이다([rank.md](./game/rank.md)). 앱이 글자로 바꿔 보여준다.
- 서버는 새 enum 값을 옛 앱이 받을 수 있는 곳에 쓰지 않는다([dev_rules.md](./dev_rules.md)의 커밋과 배포). 그래서 앱은 모르는 enum 값과 모르는 오류 코드를 받아도 멈추지 않고 기본 표시를 하도록 만든다.

## Firestore

### `configs/app`

앱, Functions, 대국 서버가 같이 읽는 운영 설정이다. 필드 목록은 [server.md](./server.md)의 "configs/app"에 모은다.

| 읽기 | 쓰기 |
|---|---|
| 누구나 (로그인 전 포함) | Functions (Admin 웹의 Callable) |

### `users/{uid}`

다른 사용자에게도 보이는 공개 프로필이다. 첫 가입의 닉네임 정하기에서 Functions가 만든다.

| 필드 | 타입 | 쓰는 쪽 | 설명 |
|---|---|---|---|
| `nickname` | string | Functions | 현재 닉네임 |
| `rankLevel` | number | 대국 서버 (처음 값 1은 Functions) | 급수 |
| `stats` | map | 대국 서버 | `games`, `wins`, `losses` (number). 온라인 대국을 모두 센다(종류와 급수 대국 여부 상관없음, 2026-11-03). `finalizeGame`이 기보와 같은 트랜잭션에서 더한다 |
| `createdAt` | timestamp | Functions | 가입 시각 |

- 읽기: 로그인한 사용자. 쓰기: 클라이언트 없음.
- 레이팅은 여기 두지 않는다. 사용자에게 보이지 않는 값이다([rank.md](./game/rank.md)).

### `users/{uid}/blocks/{blockedUid}`

차단 목록이다. 앱이 직접 쓴다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `createdAt` | timestamp | 차단한 시각 |

- 읽기·만들기·지우기: 본인만. 고치기는 막는다. 만들 때 필드는 `createdAt` 하나이고 서버 시각(`request.time`)이어야 한다. 나를 차단할 수는 없다.
- 대국 서버가 신청을 전달할 때 받는 사람의 차단 목록을 읽는다. 채팅 숨기기는 앱이 이 목록으로 거른다.

### `users_private/{uid}`

본인만 보는 정보다.

| 필드 | 타입 | 쓰는 쪽 | 설명 |
|---|---|---|---|
| `challengesEnabled` | boolean | 앱(본인), Functions(처음 값 `true`) | 설정의 "대국 신청 받기" |
| `rankProgress` | number | 대국 서버 | 현재 급수 구간 안에서의 위치 0~1. 진행 막대에 쓴다 |
| `winsToNextRank` | number? | 대국 서버 | "4급까지 약 3승"의 어림 승수. 9단이거나 아직 급수 대국을 두지 않았으면 null(Functions가 null로 만든다) |
| `nicknameChangeCount` | number | Functions | 닉네임을 바꾼 횟수. 첫 변경 무료 판단에 쓴다. 엽전이 생기기 전까지는 1이면 더 바꿀 수 없다 |
| `nicknameChangedAt` | timestamp? | Functions | 마지막으로 바꾼 시각. 7일 제한에 쓴다 |
| `sanction` | map? | Functions, 앱(본인, 경고 지우기) | 지금 걸린 제재. `type`(SanctionType), `endsAt`(timestamp?, 영구 정지와 경고는 null), `reason`(string). 끝난 제재는 `expireSanctions`가 지운다 |

- 읽기: 본인. 쓰기: 본인은 `challengesEnabled`를 바꾸고, 지금 제재가 경고이면 `sanction`을 null로 지울 수 있다(제재 팝업을 확인한 뒤, 2026-11-03 구현). 다른 제재는 지우거나 바꾸지 못한다.

### `ratings/{uid}` — 서버 전용

| 필드 | 타입 | 설명 |
|---|---|---|
| `rating` | number | 레이팅. 소수 그대로 저장한다 |
| `ratedGames` | number | 급수에 반영된 대국 수. K 값을 고르는 데 쓴다 |
| `updatedAt` | timestamp | |

- 대국 서버가 첫 급수 대국을 끝낼 때 만든다. 문서가 없으면 처음 레이팅([rank.md](./game/rank.md))으로 본다.

### `nicknames/{nicknameKey}` — 서버 전용

닉네임 중복을 막는 예약 문서다. Functions가 `users/{uid}`와 같은 트랜잭션에서 만들고 지운다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `uid` | string | 주인 |
| `createdAt` | timestamp | |

- `nicknameKey`는 영문을 소문자로 바꾼 닉네임이다(제안: 영문 대소문자만 다른 닉네임은 같은 것으로 본다).

### `nickname_changes/{changeId}` — 서버 전용

Admin 웹에서 보는 닉네임 변경 기록이다([screens.md](./screens.md)의 닉네임 바꾸기). Functions `changeNickname`이 바꿀 때마다 자동 ID로 하나 만든다.

| 필드 | 타입 |
|---|---|
| `uid` | string |
| `before` | string |
| `after` | string |
| `changedAt` | timestamp |

- 색인: `uid` + `changedAt` 내림차순(Admin 웹의 사용자 기록).

### `player_states/{uid}`

사용자가 지금 무엇을 하고 있는지다. 대국 서버가 한 사람이 대기열, 방, 대국, 신청 중 한 가지에만 있도록 트랜잭션으로 관리한다. 앱은 자기 문서를 실시간으로 듣고 화면을 옮긴다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `quickQueueJoinedAt` | timestamp? | 빠른 대국 대기열에 들어간 시각 |
| `roomId` | string? | 들어가 있는 방 |
| `gameId` | string? | 진행 중(상차림 포함) 대국. 끝나면 null |
| `lastGameId` | string? | 마지막으로 끝난 대국. 결과 화면과 다시 두기에 쓴다 |
| `outgoingChallengeId` | string? | 내가 보내고 응답을 기다리는 신청 |
| `incomingChallengeId` | string? | 내가 받고 응답하지 않은 신청 |
| `setupDraft` | map? | 상차림 화면에서 골라 둔 것. `gameId`, `formation`(Formation). 상대에게 보이면 안 되므로 여기 둔다 |
| `lastRankChange` | map? | 마지막 급수 대국의 변동. `gameId`, `rankLevelBefore`, `rankLevelAfter`, `rankProgressBefore`, `rankProgressAfter` |
| `updatedAt` | timestamp | |

- 읽기: 본인. 쓰기: 대국 서버.
- 홈의 "대국으로 돌아가기"는 `gameId`가 있으면 보여준다.

### `quick_queue/{uid}` — 서버 전용

| 필드 | 타입 | 설명 |
|---|---|---|
| `rating` | number | 들어올 때의 레이팅 |
| `joinedAt` | timestamp | 기다리기 시작한 시각. 매칭 범위 넓히기에 쓴다 |

- 매칭은 `rating`으로 범위 쿼리와 정렬을 한다. 필드 하나의 쿼리라 자동 색인으로 충분하다.

### `rooms/{roomId}`

방이다. 대국이 끝나도 방장이 나가기 전까지 유지한다([matching.md](./game/matching.md)의 방 유지).

| 필드 | 타입 | 설명 |
|---|---|---|
| `hostUid` | string | 방장 |
| `host` | map | `nickname`, `rankLevel`. 방 목록 표시용 |
| `guestUid` | string? | 상대 |
| `guest` | map? | `nickname`, `rankLevel` |
| `status` | RoomStatus | |
| `listed` | boolean | 방 목록에 공개 |
| `hostSide` | SideChoice | 방장의 진영. 접장기면 쓰지 않는다 |
| `handicap` | map? | `remover`(HandicapRemover), `pieces`(HandicapPiece 배열) |
| `rankRange` | map? | `min`, `max` (rankLevel). 공개 방에서만 쓴다 |
| `gameId` | string? | 진행 중이거나 마지막으로 둔 대국 |
| `kickedUids` | array | 내보낸 사람. 방이 닫힐 때까지 다시 들어올 수 없다 |
| `hostAbsentSince` | timestamp? | `checkRoom` 예약 작업이 방장의 연결이 없는 것을 처음 본 시각. 연결이 있으면 null |
| `guestAbsentSince` | timestamp? | 같은 기록의 상대 쪽. 상대가 없거나 연결이 있으면 null |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

- 읽기: 로그인한 사용자가 ID로 읽는다(`get`). 목록 조회(`list`)는 `listed == true`이고 `status == waiting`인 조건만 허용한다. 비공개 방은 링크(방 ID)를 아는 사람만 읽는다.
- 쓰기: 대국 서버.
- 방 ID는 추측할 수 없게 20자 임의 문자열(영문, 숫자)로 만든다. 초대 링크에 들어간다.
- 방장이 나가 닫힌 방(`closed`)도 문서를 남긴다. 방 대기실에 있던 상대가 닫힌 것을 보고, 같은 링크로 들어오려는 사람에게 `roomClosed`를 알리기 위해서다. 닫힌 방을 언제 지울지는 미정이다.
- 색인: `listed` + `status` + `createdAt` 내림차순(방 목록, `server/firestore.indexes.json`).

### `challenges/{challengeId}`

대국 신청이다. 받는 사람과 보내는 사람 모두 한 번에 하나만 가진다([matching.md](./game/matching.md)).

| 필드 | 타입 | 설명 |
|---|---|---|
| `fromUid` | string | 신청한 사람 |
| `from` | map | `nickname`, `rankLevel`. 수락 팝업 표시용 |
| `toUid` | string | 받는 사람 |
| `roomId` | string? | 방 대기실의 접속자 초대면 그 방. 수락하면 방에 들어간다 |
| `senderSide` | SideChoice? | 신청한 사람의 진영. 접장기면 쓰지 않는다 |
| `handicap` | map? | `remover`(HandicapRemover, 신청한 사람 기준), `pieces` |
| `timeControl` | map | 수락하면 둘 대국의 시간 규칙. RTDB `meta/timeControl`과 같다. 팝업의 조건 칩에 쓴다 |
| `status` | ChallengeStatus | |
| `expiresAt` | timestamp | 응답 마감. 팝업의 남은 시간 막대에 쓴다 |
| `gameId` | string? | 수락해서 만든 대국 |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

- 읽기: `fromUid` 또는 `toUid` 본인이 ID로 읽는다(`get`). 목록은 막는다. 쓰기: 대국 서버.
- 신청 ID는 20자 임의 문자열(영문, 숫자)이다.
- 방 초대면 `senderSide`와 `handicap`에 방 조건을 복사한다.
- 받는 사람이 보내는 사람을 차단해 전달하지 않은 신청도 문서 모양은 같다. 보내는 사람이 읽을 수 있으므로 전달 여부를 적지 않는다.

### `challenge_limits/{fromUid}_{toUid}` — 서버 전용

같은 상대에게 신청을 남발하지 못하게 하는 기록이다([matching.md](./game/matching.md)의 로비와 신청).

| 필드 | 타입 | 설명 |
|---|---|---|
| `failCount` | number | 거절되거나 응답을 받지 못한 연속 횟수. 수락되거나 `challengeFailLimit`에 닿아 `blockedUntil`을 정하면 0 |
| `blockedUntil` | timestamp? | 이 시각까지 신청할 수 없다 |
| `updatedAt` | timestamp | |

### `games_archived/{gameId}`

끝난 대국의 기보와 결과다([notation.md](./game/notation.md)의 기보). 대국 서버가 대국을 끝낼 때 레이팅 반영과 같은 트랜잭션에서 만든다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `mode` | GameMode | |
| `rated` | boolean | 급수 반영 대국 |
| `roomId` | string? | |
| `playerUids` | array | `[초 uid, 한 uid]`. 내 기보 목록 조회용 |
| `pairKey` | string | 두 uid를 정렬해 `_`로 이은 값. 나와의 전적 조회용 |
| `players` | map | `cho`, `han` 각각 `uid`, `rankLevel`(대국 시작 때) |
| `handicap` | array? | 한에서 뗀 HandicapPiece |
| `timeControl` | map | 아래 RTDB `meta/timeControl`과 같다 |
| `initialFen` | string | 상차림과 접장기가 반영된 처음 국면 |
| `moves` | array | 수 표기 문자열 |
| `moveTimesMs` | array | 각 수에 쓴 시간(밀리초) |
| `result` | map | `winner`(Side), `reason`(GameEndReason), `choScore`, `hanScore` (number) |
| `rematchOf` | string? | 다시 두기로 만든 대국이면 앞 대국 |
| `startedAt` | timestamp | 상차림을 시작한 시각 |
| `endedAt` | timestamp | |

- 읽기: 로그인한 사용자. 쓰기: 대국 서버.
- 닉네임은 저장하지 않는다. 이전 닉네임을 다른 사용자에게 보여주지 않기 위해서다([screens.md](./screens.md)의 내 정보). 앱은 `users/{uid}`의 현재 닉네임을 읽어 보여준다.
- 색인: `playerUids` array-contains + `endedAt` 내림차순, `pairKey` + `endedAt` 내림차순(`server/firestore.indexes.json`).
- 앱의 조회(2026-11-03 구현)
  - 내 기보 목록: `playerUids` array-contains 내 uid, `endedAt` 내림차순으로 20개씩. 다음 쪽은 마지막 기보의 `endedAt`보다 앞인 것을 읽는다.
  - 내 정보: 같은 조회로 최근 10개, 오늘 전적은 오늘 0시(기기 시간대) 이후 `endedAt`.
  - 나와의 전적: 세기 쿼리(`count()`) 세 번. `pairKey` 전체, 내가 초이고 초가 이긴 판, 내가 한이고 한이 이긴 판. 모두 같음 조건이라 복합 색인이 없어도 된다.

### `reports/{reportId}` — 서버 전용

채팅 메시지 신고다([moderation.md](./moderation.md)). Functions가 만들고 Admin 웹은 Callable로만 읽고 바꾼다. `reportId`는 `{messageId}_{reporterUid}`라 한 사람이 한 메시지를 한 번만 신고한다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `reporterUid` | string | |
| `targetUid` | string | 신고된 메시지를 보낸 사람 |
| `channel` | ChatChannel | |
| `gameId` | string? | 대국·관전 채팅이면 그 대국 |
| `message` | map | 신고된 메시지 사본. `messageId`, `uid`, `nickname`, `text`, `sentAt` |
| `context` | array | 앞뒤 메시지 사본. 모양은 `message`와 같다 |
| `check` | map? | 신고된 메시지의 검사 결과 사본. 아래 `chat_checks`와 같다 |
| `status` | ReportStatus | |
| `resolution` | map? | `action`(`dismissed` 또는 SanctionType), `reason`, `adminUid`, `sanctionId?` |
| `createdAt` | timestamp | |
| `resolvedAt` | timestamp? | |
| `expiresAt` | timestamp? | 처리가 끝나면 1년 뒤로 정한다. TTL 정책으로 지운다 |

- `resolution.action`이 SanctionType이면 `sanctionId`가 그 제재다. 같은 메시지의 다른 처리 전 신고도 같은 `resolution`으로 함께 닫는다([server.md](./server.md)의 신고 처리와 제재).
- 색인: `status` + `createdAt` 오름차순(처리 전 대기열), `status` + `resolvedAt` 내림차순(처리한 신고), `targetUid` + `createdAt` 내림차순(피신고자의 신고된 기록). 같은 메시지의 신고는 `message.messageId`와 `status` 같음 조건이라 복합 색인이 없어도 된다.

### `moderation_logs/{logId}` — 서버 전용

검사에 걸린 메시지 기록이다. 1년 보관한다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `uid` | string | 보낸 사람 |
| `channel` | ChatChannel | |
| `gameId` | string? | |
| `text` | string | 원문 |
| `categories` | array | 걸린 분류. 금칙어에 걸려 OpenAI에 보내지 않았으면 빈 배열 |
| `scores` | map | 분류별 점수. 금칙어에 걸렸으면 빈 map |
| `bannedWordMatched` | boolean | 자체 금칙어 일치 |
| `createdAt` | timestamp | |
| `expiresAt` | timestamp | 1년 뒤. TTL 정책으로 지운다 |

- 색인: `uid` + `createdAt` 내림차순(Admin 웹의 사람별 검사 기록). 전체 목록은 `createdAt` 단일 필드 색인을 쓴다.

### `chat_checks/{messageId}` — 서버 전용

검사를 통과해 저장된 메시지의 검사 결과다. 신고할 때 함께 저장하기 위해 남긴다. 채팅과 같이 90일 보관한다.

| 필드 | 타입 |
|---|---|
| `scores` | map |
| `bannedWordMatched` | boolean |
| `expiresAt` | timestamp |

### `sanctions/{sanctionId}` — 서버 전용

제재 이력이다. 지금 걸린 제재는 `users_private/{uid}.sanction`에도 쓴다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `uid` | string | |
| `type` | SanctionType | |
| `startsAt` | timestamp | |
| `endsAt` | timestamp? | 영구 정지와 경고는 null |
| `reason` | string | |
| `reportId` | string? | |
| `adminUid` | string? | 자동 제재면 null |
| `createdAt` | timestamp | |

- 채팅 제한과 이용 정지는 `endsAt`이 `startsAt`에서 1·7·30일 뒤다. 경고는 아직 막고 있는 제재가 있으면 이력에만 남고 `users_private.sanction`을 바꾸지 않는다([server.md](./server.md)의 신고 처리와 제재).
- 색인: `uid` + `createdAt` 내림차순(Admin 웹의 제재 이력).

## Realtime Database

### `games_active/{gameId}`

진행 중이거나 막 끝난 대국이다. 관전을 위해 누구나 읽는다. 끝나고 일정 시간이 지나면 대국 서버가 지운다([server.md](./server.md)의 서버 전용 설정).

- 읽기: 누구나. 쓰기: 대국 서버.
- 대국 서버는 이 노드 전체를 ETag 조건부 쓰기로 바꿔 동시에 들어온 요청이 서로 덮어쓰지 않게 한다.

#### `meta` — 대국을 만들 때 쓰고 바꾸지 않는다

| 필드 | 타입 | 설명 |
|---|---|---|
| `mode` | GameMode | |
| `rated` | boolean | |
| `roomId` | string? | |
| `listed` | boolean | 관전 목록에 보인다. 비공개 방 대국은 false |
| `players` | map | `cho`, `han` 각각 `uid`, `nickname`, `rankLevel` |
| `handicap` | array? | 한에서 뗀 HandicapPiece |
| `timeControl` | map | `baseMs`(기본 시간), `periodMs`(초읽기 한 번), `periods`(초읽기 횟수), `setupMs`(상차림 시간), `extensionPeriods`(연장 1회에 늘어나는 횟수), `extensionLimit`(연장 최대 횟수) |
| `disconnectLimitMs` | number | 대국을 만들 때의 `configs/app.disconnectLimitSeconds`. 대국 중에 설정이 바뀌어도 이 값을 쓴다 |
| `rematchOf` | string? | |
| `rematchCount` | number | 빠른 대국에서 같은 상대와 연달아 다시 둔 횟수. 첫 대국은 0 |
| `createdAt` | ms | |

#### `state`

| 필드 | 타입 | 설명 |
|---|---|---|
| `version` | number | 쓸 때마다 1씩 는다 |
| `phase` | GamePhase | |
| `setup` | map | `turn`(Side, 지금 고르는 쪽), `startsAt`(ms, 상차림을 시작한 시각. 대국을 만든 시각과 같다), `deadlineAt`(ms), `han`(Formation?), `cho`(Formation?) |
| `initialFen` | string? | 양쪽 상차림이 끝나면 쓴다 |
| `turn` | Side? | 둘 차례 |
| `turnStartedAt` | ms? | 지금 차례가 시작된 서버 시각 |
| `clock` | map | `cho`, `han` 각각 `baseMs`(남은 기본 시간), `periods`(남은 초읽기 횟수), `extensionsUsed`. 차례가 넘어갈 때만 바꾼다 |
| `disconnect` | map | `cho`, `han` 각각 `usedMs`(지금까지 끊긴 시간 합계), `since`(ms?, 지금 끊겨 있으면 끊긴 시각) |
| `extensionNotice` | map? | 마지막 시간 연장. `side`, `at`(ms). 상대 화면 표시용 |
| `result` | map? | `winner`, `reason`, `choScore`, `hanScore` |
| `endedAt` | ms? | |

#### `moves/{index}`

| 필드 | 타입 | 설명 |
|---|---|---|
| `m` | string | 수 표기(`b1c3`, `pass`) |
| `spentMs` | number | 이 수에 쓴 시간 |

#### `rematch`

| 필드 | 타입 | 설명 |
|---|---|---|
| `cho`, `han` | boolean? | 다시 두기를 눌렀다 |
| `cancelled` | boolean? | 한쪽이 결과 화면을 나가서 취소됐다 |
| `gameId` | string? | 두 쪽이 모두 눌러 정한 새 대국. 새 대국을 만들기 전에 정하므로, 앱은 내 `player_states.gameId`가 이 값이 되면 옮겨 간다. 만들지 못하면 지우고 `cancelled`를 쓴다 |
| `blocked` | boolean? | 빠른 대국의 `quickRematchLimit`에 닿아 다시 두기를 쓸 수 없다. 대국을 만들 때 쓴다 |

### `spectate_list/{gameId}`

관전 목록 카드다. `games_active` 전체를 받지 않고 목록을 그리기 위해 따로 둔다. 관전 목록에 보이는 대국만 있다(비공개 방 대국 제외). 상차림이 끝나 판이 생긴 뒤에 만들고(상차림 중에는 국면이 없다), 대국이 끝나면 지운다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `players` | map | `cho`, `han` 각각 `nickname`, `rankLevel` |
| `fen` | string | 지금 국면. 판 미리보기 |
| `moveCount` | number | |
| `handicapped` | boolean | 접장기 표시 |
| `spectatorCount` | number | |
| `startedAt` | ms | |

- 읽기: 누구나(목록 전체). 쓰기: 대국 서버(대국 상태를 쓸 때마다 갱신).
- 정렬(관전자 많은 순, 급수 높은 순, 10수 미만은 뒤)은 앱이 한다.

### `spectators/{gameId}/{viewerId}`

관전자 수를 세는 표시다. 로그인하지 않은 관전자도 센다([screens.md](./screens.md)의 관전 목록).

- 값: `ms` 들어온 시각.
- `viewerId`는 앱이 관전 화면을 열 때마다 만드는 20자 임의 문자열이다. 앱은 쓰고 나서 `onDisconnect`로 지운다.
- 읽기: 막는다(대국 서버만 센다). 쓰기: 누구나. 새로 만들 때 값은 서버 시각(`now`)이어야 하고, `viewerId`가 20자이고 `games_active/{gameId}`가 있어야 한다. 고치기는 막고 지우기는 허용한다.
- 대국 서버가 `games_active/{gameId}`를 지울 때 `spectators/{gameId}`와 `spectate_list/{gameId}`도 지운다.
- 일부러 숫자를 부풀리는 것은 규칙으로 막지 못한다. 문제가 되면 로그인한 관전자만 세도록 바꾼다.

### `connections/{uid}/{connectionId}`

앱의 접속 상태다. 접속 끊김 판정([server.md](./server.md)의 접속 끊김)에 쓴다. `connectionId`는 RTDB 연결마다 앱이 만드는 키다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `online` | boolean | 연결되어 있다. 앱이 `onDisconnect`로 false를 걸어 둔다. 숨긴 웹 탭은 `lastSeenAt`(서버 시각)도 함께 걸어 둔다 |
| `foreground` | boolean | 앱이 화면에 떠 있다. 다른 앱으로 넘어가면 false. 웹은 탭이 숨겨져도 true다 |
| `activeSince` | ms | `online`이고 `foreground`가 된 시각 |
| `lastSeenAt` | ms | 마지막으로 살아 있음을 알린 시각. 대국 중에는 주기적으로 갱신하고, 다른 앱으로 넘어갈 때도 갱신한다 |
| `tabHidden` | boolean? | 웹 탭이 숨겨져 있다. 웹만 쓰고 앱은 쓰지 않는다(없으면 숨겨지지 않은 것). 웹은 탭이 숨겨져도 `foreground`를 true로 둔다([server.md](./server.md)의 접속 끊김) |

- 읽기: 로그인한 사용자가 `uid`로 읽는다. `connections` 전체 목록은 막는다. 쓰기: 본인.
- 연결마다 네 필드가 모두 있어야 하고 `tabHidden`(boolean, 선택) 말고 다른 필드는 막는다. `activeSince`와 `lastSeenAt`은 서버 시각(`now`)이거나 이미 있는 값 그대로여야 한다(`onDisconnect`의 `online: false`처럼 다른 필드만 바꾸는 쓰기).
- 앱은 연결할 때 자기 `uid` 아래의 지난 연결 키를 지운다.

### `online_users/{uid}`

대국실 접속자 목록이다. 로그인하고 앱을 화면에 켜 둔 사람을 모두 보여준다([matching.md](./game/matching.md)의 접속자와 로비 노출).

| 필드 | 타입 | 쓰는 쪽 | 설명 |
|---|---|---|---|
| `nickname` | string | 대국 서버 | |
| `rankLevel` | number | 대국 서버 | |
| `status` | OnlineStatus | 대국 서버 | 대국(상차림 포함) 중이면 `playing` |
| `challengesEnabled` | boolean | 대국 서버, 앱(본인) | 신청 받기. false면 "신청 받지 않음"으로 보여준다 |
| `since` | ms | 대국 서버 | 들어온 시각 |

- 읽기: 로그인한 사용자. 쓰기: 대국 서버. 본인은 자기 항목을 지우거나(`onDisconnect`) `challengesEnabled`만 바꿀 수 있다. `challengesEnabled`는 항목이 있을 때만 boolean으로 바꾸고 지우지 못한다.
- 닉네임과 급수를 앱이 쓰면 속일 수 있으므로 대국 서버가 쓴다.

### `chats_lobby/{messageId}`, `chats_game/{gameId}/{messageId}`, `chats_spectator/{gameId}/{messageId}`

채팅 메시지다. 세 경로의 메시지 모양은 같다. Functions가 검사를 통과한 메시지만 쓴다([moderation.md](./moderation.md)).

| 필드 | 타입 | 설명 |
|---|---|---|
| `uid` | string | |
| `nickname` | string | 보낼 때의 닉네임 |
| `text` | string | |
| `sentAt` | ms | |

| 경로 | 읽기 |
|---|---|
| `chats_lobby` | 로그인한 사용자 |
| `chats_game/{gameId}` | 그 대국의 두 대국자 (`games_active/{gameId}/meta/players`로 확인) |
| `chats_spectator/{gameId}` | 로그인한 사용자. 대국자는 대국이 끝난 뒤에만 |

- 쓰기: Functions만. 90일 지난 메시지는 Functions 예약 작업이 지운다.
- 대국자 확인은 `games_active/{gameId}`로 하므로 대국이 RTDB에서 지워지면 대국자도 대국 채팅을 읽지 못한다. 관전 채팅은 대국이 지워지면 로그인한 사용자 누구나 읽는다(2026-11-03 구현).
- `chats_lobby`는 `sentAt` 색인을 둔다(지난 메시지 지우기). 앱은 키 순서로 최근 100개를 듣는다.
- 차단한 사람의 메시지는 앱이 `users/{uid}/blocks`로 걸러 숨긴다.

## 보안 규칙 방향

Firestore와 RTDB 모두 기본 거부에서 시작한다([dev_rules.md](./dev_rules.md)의 보안 규칙).

| 위치 | 비로그인 | 로그인 | 본인 | 서버 |
|---|---|---|---|---|
| `configs/app` | 읽기 | 읽기 | | Functions 쓰기 |
| `users` | | 읽기 | | Functions, 대국 서버 쓰기 |
| `users/{uid}/blocks` | | | 읽기, 만들기, 지우기 | 대국 서버 읽기 |
| `users_private` | | | 읽기, `challengesEnabled` 쓰기, 경고 지우기 | Functions, 대국 서버 쓰기 |
| `player_states` | | | 읽기 | 대국 서버 쓰기 |
| `rooms` | | ID 읽기, 공개 대기 방 목록 | | 대국 서버 쓰기 |
| `challenges` | | | 보낸 사람·받는 사람 읽기 | 대국 서버 쓰기 |
| `games_archived` | | 읽기 | | 대국 서버 쓰기 |
| `ratings`, `nicknames`, `nickname_changes`, `quick_queue`, `challenge_limits`, `reports`, `moderation_logs`, `chat_checks`, `sanctions` | | | | 서버 전용 |
| RTDB `games_active`, `spectate_list` | 읽기 | 읽기 | | 대국 서버 쓰기 |
| RTDB `spectators` | 만들기, 지우기 | 만들기, 지우기 | | 대국 서버 읽기 |
| RTDB `connections` | | 읽기 | 쓰기 | 대국 서버 읽기 |
| RTDB `online_users` | | 읽기 | 지우기, `challengesEnabled` 쓰기 | 대국 서버 쓰기 |
| RTDB `chats_*` | | 경로별 읽기 | | Functions 쓰기 |

- Admin 웹은 어느 컬렉션도 직접 읽지 않고 Callable로만 다룬다([dev_rules.md](./dev_rules.md)의 Admin 웹 규칙). `admin: true` claim이 있는 관리자도 보안 규칙에서는 일반 사용자와 같다. 관리자 확인은 Admin Callable이 한다(2026-11-03 구현, 에뮬레이터 테스트로 확인).
- 허용과 거부를 함께 에뮬레이터 테스트로 확인한다.

## 보관과 삭제

| 데이터 | 보관 | 지우는 방법 |
|---|---|---|
| RTDB `games_active` | 끝나고 몇 분 | 대국 서버 정리 작업 |
| RTDB `chats_*` | 90일 | Functions 예약 작업 |
| `chat_checks` | 90일 | Firestore TTL (`expiresAt`) |
| `moderation_logs` | 1년 | Firestore TTL |
| `reports` | 처리 뒤 1년 | Firestore TTL |
| `games_archived` | 계속 | |

## 미정

- 닫힌 방(`rooms`의 `status == closed`)을 지우는 때와 방법(TTL 또는 정리 작업).
- 회원 탈퇴 때 지울 데이터와 남길 데이터. 기보(`games_archived`)는 uid만 남기고 앱이 "탈퇴한 사용자"로 보여주는 안을 검토한다.
- 자체 금칙어 목록을 둘 곳(`config.ts` 또는 서버 전용 Firestore 문서)과 Admin 웹에서 고칠 수 있게 할지. 지금은 `config.ts`의 `BANNED_WORDS`다.
