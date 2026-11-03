# 대국 서버 (`server/game`)

Cloud Run에서 도는 Dart 대국 서버다. 설계는 [docs/server.md](../../docs/server.md), 데이터는 [docs/database.md](../../docs/database.md), 코드 규칙은 [docs/dev_rules.md](../../docs/dev_rules.md)의 "Dart 대국 서버 규칙"을 따른다.

구현 순서 9번(접속자와 신청)까지 있다. 대국 API는 `setFormation`, `playMove`, `resign`, `checkGame`, `requestRematch`, `leaveResult`, 매칭 API는 `joinQuickQueue`, `leaveQuickQueue`, 방 API는 `createRoom`, `joinRoom`, `leaveRoom`, `kickGuest`, `startRoomGame`, 접속자와 신청 API는 `enterLobby`, `sendChallenge`, `respondChallenge`, `cancelChallenge`, 예약 작업은 `/tasks/evaluateGame`(상차림 마감, 시간패, 접속 끊김 마감), `/tasks/finalizeGame`(기보 저장, 레이팅·급수 반영, 대국자 풀기, 방을 `waiting`으로), `/tasks/cleanupGame`(RTDB 정리), `/tasks/retryQuickMatch`(매칭 범위 넓히기), `/tasks/checkRoom`(방장·상대 연결 확인), `/tasks/expireChallenge`(신청 응답 마감)이다. 판정은 `lib/services/game_rules.dart`, 레이팅과 급수는 `lib/services/rating_rules.dart`(둘 다 순수 함수), 쓰기와 예약은 `lib/services/game_service.dart`(대국), `quick_match_service.dart`(대기열과 매칭), `room_service.dart`(방), `rematch_service.dart`(다시 두기), `lobby_service.dart`(접속자 목록), `challenge_service.dart`(신청)에 있다. 접속 끊김은 판정마다 RTDB `connections`(앱이 쓴다)를 읽어 센다.

방과 신청이 생기기 전에 아는 두 계정의 대국을 만들 때는 에뮬레이터 전용 개발용 API `devCreateGame`(`opponentNickname`, `side`)을 쓴다. 앱 개발 빌드의 홈에 있는 "개발용 온라인 대국" 카드가 이것을 부른다.

## 구조

| 경로 | 내용 |
|---|---|
| `bin/server.dart` | 진입점. 환경 변수를 읽고 서버를 켠다 |
| `lib/game_server.dart` | 의존성 조립과 경로 등록. 운영과 에뮬레이터의 차이는 `GameServer.create`에만 있다 |
| `lib/server_environment.dart` | 환경 변수(운영·에뮬레이터, 주소, Cloud Tasks) |
| `lib/config.dart` | 대국 서버만 쓰는 설정(`docs/dev_rules.md`의 설정 저장) |
| `lib/http/` | Callable 프로토콜(`callable.dart`, `callable_handler.dart`), 예약 작업 경로(`task_handler.dart`), CORS·trace 미들웨어 |
| `lib/auth/` | Firebase ID token 검사, Cloud Tasks OIDC 토큰 검사, JWT·공개 키 |
| `lib/firebase/` | Firestore·RTDB REST 클라이언트, 액세스 토큰 |
| `lib/repositories/` | 컬렉션·경로별 repository. DB 접근은 여기서만 한다 |
| `lib/models/` | DB 문서 모델(`json_serializable`) |
| `lib/tasks/` | `TaskScheduler`와 Cloud Tasks·에뮬레이터 구현 |
| `lib/endpoints/` | API와 예약 작업. 파일마다 `validateParams()`를 둔다 |
| `lib/services/` | 대국 판정(`game_rules.dart`)과 레이팅·급수 계산(`rating_rules.dart`)은 DB에 닿지 않는 순수 함수, 대국 흐름(`game_service.dart`), 빠른 대국(`quick_match_service.dart`), 방(`room_service.dart`), 다시 두기(`rematch_service.dart`), 접속자 목록(`lobby_service.dart`), 신청(`challenge_service.dart`) |

### API 추가하기

1. `lib/endpoints/<api>.dart`에 `CallableEndpoint`를 만든다. `handle`은 `final requestParams = data;`로 받고, 파라미터가 있으면 같은 파일의 `validateParams(requestParams)`를 먼저 부른다.
2. 앱에 보여줄 실패는 `CallableException`으로 던진다. 사유는 `GameErrorCode`(`docs/server.md`의 오류 코드 표)로 알린다.
3. `GameServer.create`의 `callables`에 넣는다. 경로는 `POST /<name>`이다.
4. 로그인과 `users/{uid}` 확인은 `createCallableHandler`가 먼저 한다. 프로필이 없으면 `profileRequired`.
5. 정상 처리에는 `logger.info` 성공 로그를 하나 남긴다.

예약 작업은 `TaskName`에 이름을 더하고 `TaskEndpoint`를 만들어 `tasks`에 넣는다. 경로는 `POST /tasks/<name>`이다. 같은 작업이 늦게 돌거나 두 번 돌아도 결과가 같게 만든다.

## Firebase 연결

Dart용 Firebase Admin SDK가 공식으로 없어 REST API를 직접 부른다(`lib/firebase/`).

| | 에뮬레이터 | 운영 |
|---|---|---|
| Firestore | `http://127.0.0.1:8080`, `Bearer owner`(보안 규칙 건너뜀) | `https://firestore.googleapis.com`, 서비스 계정 토큰 |
| RTDB | `http://127.0.0.1:9000/?ns=janggi-go-default-rtdb` | `https://janggi-go-default-rtdb.asia-southeast1.firebasedatabase.app` |
| ID token | Auth 에뮬레이터의 서명 없는 토큰. 클레임(`aud`, `iss`, `exp`)만 확인 | Google 공개 키로 RS256 서명과 클레임 확인 |
| 예약 작업 | 같은 프로세스의 타이머(`LocalTaskScheduler`)가 `/tasks/...`를 부른다 | Cloud Tasks가 OIDC 토큰을 붙여 부른다 |
| 로그 | 터미널용 한 줄 | Cloud Logging JSON(`severity`, trace) |

에뮬레이터 RTDB는 `firebase.json`과 같은 인스턴스 이름(`janggi-go-default-rtdb`)을 쓴다. 앱과 Functions도 에뮬레이터에서 같은 이름으로 붙어야 대국 서버가 쓴 값을 본다.

### Firestore 에뮬레이터의 제약

- 트랜잭션 안의 읽기는 `documents:batchGet`(POST)으로 한다. 에뮬레이터 REST는 GET의 `transaction` 쿼리를 읽지 못하고 연결을 끊는다.
- 같은 문서를 두 트랜잭션이 동시에 바꾸면 에뮬레이터는 30초 뒤 `Transaction lock timeout`으로 끝내고 REST 연결을 끊는다. 운영 Firestore는 바로 `ABORTED`를 돌려주고 `FirestoreClient.runTransaction`이 다시 실행한다. 그래서 동시 매칭 같은 경합은 에뮬레이터에서 `callable 실패`(INTERNAL)로 보일 수 있다.

## 환경 변수

| 이름 | 필요한 때 | 설명 |
|---|---|---|
| `GAME_ENV` | 운영 | `production`이면 운영 Firebase에 붙는다. 없으면 에뮬레이터 |
| `PORT` | 운영 | 듣는 포트. Cloud Run이 넣는다. 에뮬레이터에서 없으면 8090 |
| `GAME_SERVER_URL` | 운영 | 이 서비스의 Cloud Run 주소. 예약 작업 주소와 OIDC audience |
| `TASKS_QUEUE` | 운영 | Cloud Tasks 큐 이름(리전 `asia-northeast3`) |
| `TASKS_SERVICE_ACCOUNT` | 운영 | 예약 작업의 OIDC 토큰을 만드는 서비스 계정 이메일 |
| `GCLOUD_PROJECT` | 에뮬레이터, 선택 | `demo-`로 시작해야 한다. 없으면 `demo-janggi-go` |
| `FIRESTORE_EMULATOR_HOST`, `FIREBASE_DATABASE_EMULATOR_HOST` | 에뮬레이터, 선택 | 없으면 `firebase.json`의 포트 |

Cloud Run(`K_SERVICE`가 있는 곳)에서 `GAME_ENV=production` 없이 켜지면 서명 없는 토큰을 받게 되므로 시작하지 않는다.

## 로컬 실행

1. 에뮬레이터를 띄운다. `server/functions`에서:

   ```bash
   npm run emulators
   ```

   에뮬레이터는 끄면 데이터가 모두 지워진다. 띄울 때마다 다른 터미널에서 `configs/app`과 테스트 계정 네 개(닉네임까지 정한 상태, 첫 계정은 관리자)를 만든다. 계정과 비밀번호는 [seedEmulator.ts](../functions/src/scripts/seedEmulator.ts)에 있다. `emulators:export`·`--export-on-exit`는 이 PC(Windows)에서 내보낸 폴더를 옮기는 단계가 실패해서 쓰지 않는다.

   ```bash
   npm run seed
   ```

2. 대국 서버를 띄운다. `server/game`에서:

   ```bash
   dart run bin/server.dart
   ```

   `http://<개발 PC>:8090`에서 듣는다. 실제 기기는 개발 PC의 IP로 부른다.

3. 확인한다. Auth 에뮬레이터에서 계정을 만들어 ID token을 받고 개발용 API `devPing`을 부른다. 닉네임(`users/{uid}`)이 없으면 `profileRequired`로 거절되므로, 앱에서 닉네임을 정했거나 에뮬레이터 UI(`http://127.0.0.1:4000/firestore`)에서 `users/{uid}`를 만든 계정을 쓴다.

   ```bash
   curl -s -X POST "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key" -H "Content-Type: application/json" -d '{"email":"dev1@example.com","password":"password123","returnSecureToken":true}'
   ```

   ```bash
   curl -s -X POST http://127.0.0.1:8090/devPing -H "Authorization: Bearer <idToken>" -H "Content-Type: application/json" -d '{"data":{"taskDelaySeconds":3}}'
   ```

   3초 뒤 서버 로그에 `devPing task 실행`이 찍힌다.

`devPing`, `devCreateGame`, `/tasks/devPing`은 에뮬레이터에서만 열린다. `devCreateGame`은 `configs/app`을 읽으므로 1번의 `npm run seed`를 먼저 한다.

 `GET /health`는 어디서나 `ok`를 돌려준다.

## 테스트

`server/game`에서:

```bash
dart analyze
```

```bash
dart test
```

`dart test`는 에뮬레이터가 없으면 `emulator` 태그 테스트(`test/emulator/`)를 건너뛴다. 에뮬레이터까지 포함해 돌리려면 `server`에서:

```bash
firebase emulators:exec --project demo-janggi-go --only auth,firestore,database "cd game && dart test"
```

통합 테스트는 `GameServer.create`의 `test*` 인자로 대국 시간, 매칭 범위를 넓히는 간격, 방 연결 확인 간격, 신청 응답 시간과 연속 거절 제한 시간을 줄이고, 계정 준비와 API 호출은 `test/emulator/support/emulator_helpers.dart`를 같이 쓴다. 빠른 대국 테스트는 같은 에뮬레이터에 남은 대기열 항목과 만나지 않도록 계정마다 큰 레이팅을 따로 준다.

모델(`lib/models/`)을 바꾸면 코드를 다시 만들고, 만든 코드를 120자 폭으로 다시 맞춘다.

```bash
dart run build_runner build
```

```bash
dart format lib
```

## 운영 배포

2026-11-02에 처음 배포했다. 서비스 주소는 `https://game-724506591713.asia-northeast3.run.app`이며 앱 운영 빌드의 `--dart-define=GAME_SERVER_URL`에 넣는다. 처음 한 번 GCP를 설정하고, 이후에는 이미지를 만들어 배포한다. 모든 명령은 저장소 루트에서 [gcloud CLI](https://cloud.google.com/sdk/docs/install)로 실행한다.

### 처음 한 번

1. 프로젝트와 리전을 정하고 API를 켠다.

   ```bash
   gcloud config set project janggi-go
   ```

   ```bash
   gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com cloudtasks.googleapis.com
   ```

2. 이미지 저장소를 만든다.

   ```bash
   gcloud artifacts repositories create janggigo --repository-format=docker --location=asia-northeast3
   ```

3. 서비스 계정 두 개를 만든다. `game-server`는 대국 서버가 실행될 때 쓰고, `game-tasks`는 Cloud Tasks가 대국 서버를 부를 때 OIDC 토큰을 만든다.

   ```bash
   gcloud iam service-accounts create game-server --display-name="장기고 대국 서버"
   ```

   ```bash
   gcloud iam service-accounts create game-tasks --display-name="장기고 대국 서버 예약 작업"
   ```

4. `game-server`에 권한을 준다. Firestore 읽기·쓰기, RTDB 읽기·쓰기, Cloud Tasks 작업 만들기, `game-tasks`로 토큰 만들기다.

   ```bash
   gcloud projects add-iam-policy-binding janggi-go --member=serviceAccount:game-server@janggi-go.iam.gserviceaccount.com --role=roles/datastore.user
   ```

   ```bash
   gcloud projects add-iam-policy-binding janggi-go --member=serviceAccount:game-server@janggi-go.iam.gserviceaccount.com --role=roles/firebasedatabase.admin
   ```

   ```bash
   gcloud projects add-iam-policy-binding janggi-go --member=serviceAccount:game-server@janggi-go.iam.gserviceaccount.com --role=roles/cloudtasks.enqueuer
   ```

   ```bash
   gcloud iam service-accounts add-iam-policy-binding game-tasks@janggi-go.iam.gserviceaccount.com --member=serviceAccount:game-server@janggi-go.iam.gserviceaccount.com --role=roles/iam.serviceAccountUser
   ```

5. Cloud Tasks 큐를 만든다. 작업이 실패하면 간격을 늘려 다시 부르고, 같은 작업은 10번까지만 부른다.

   ```bash
   gcloud tasks queues create game-tasks --location=asia-northeast3 --max-attempts=10 --min-backoff=1s --max-backoff=60s
   ```

6. 이미지 저장소에 정리 정책을 건다. 배포할 때마다 이미지가 쌓이므로 이미지마다 최근 3개만 남긴다([cleanup-policy.json](cleanup-policy.json)). 3개보다 오래된 버전으로는 되돌릴 수 없다. `gcf-artifacts`는 Functions 배포가 만드는 저장소이며 처음 Functions를 배포한 뒤에 생긴다.

   ```bash
   gcloud artifacts repositories set-cleanup-policies janggigo --location=asia-northeast3 --policy=server/game/cleanup-policy.json --no-dry-run
   ```

   ```bash
   gcloud artifacts repositories set-cleanup-policies gcf-artifacts --location=asia-northeast3 --policy=server/game/cleanup-policy.json --no-dry-run
   ```

### 배포

1. 이미지를 만든다.

   ```bash
   gcloud builds submit --config server/game/cloudbuild.yaml --ignore-file server/game/.gcloudignore --region asia-northeast3 .
   ```

2. 처음 배포한다. 앱이 Firebase ID token으로 부르므로 인증 없는 호출을 허용하고, 인증은 대국 서버가 직접 한다. `GAME_SERVER_URL`은 아직 모르므로 임시 값을 넣는다.

   ```bash
   gcloud run deploy game --image asia-northeast3-docker.pkg.dev/janggi-go/janggigo/game:latest --region asia-northeast3 --service-account game-server@janggi-go.iam.gserviceaccount.com --allow-unauthenticated --min-instances 0 --set-env-vars GAME_ENV=production,TASKS_QUEUE=game-tasks,TASKS_SERVICE_ACCOUNT=game-tasks@janggi-go.iam.gserviceaccount.com,GAME_SERVER_URL=https://pending
   ```

3. 나온 서비스 주소(`https://game-...run.app`)로 `GAME_SERVER_URL`을 바꾼다. 예약 작업의 OIDC audience가 이 값과 같아야 한다.

   ```bash
   gcloud run services update game --region asia-northeast3 --update-env-vars GAME_SERVER_URL=<서비스 주소>
   ```

4. 확인한다. `<서비스 주소>/health`가 `ok`면 뜬 것이다.

이후 배포는 1번과 2번(`--set-env-vars` 없이 `--image`만)을 다시 한다. 서버를 먼저 배포하고 앱을 나중에 제출한다(`docs/dev_rules.md`의 커밋과 배포).
