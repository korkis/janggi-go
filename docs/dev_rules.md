# 개발 규칙

이 문서는 장기고 저장소의 코드 작성 및 작업 절차에 관한 단일 기준 문서다.

## 저장소 구성

| 경로 | 내용 |
|---|---|
| `app/` | Flutter 앱 (안드로이드, 아이폰, 웹) |
| `packages/janggi_core/` | 순수 Dart 장기 규칙 엔진. `app/`과 `server/game/`이 path 의존성으로 공유한다 |
| `server/` | Firebase 설정(`firebase.json`, `.firebaserc`)과 보안 규칙 |
| `server/functions/` | Cloud Functions (TypeScript) |
| `server/game/` | Cloud Run Dart 대국 서버 (매칭, 수 검증, 서버 시계) |
| `server/admin/` | Admin 웹 (React, 신고 처리 등 운영) |
| `tools/` | 어느 코드베이스에도 의존하지 않는 독립 스크립트 |
| `docs/` | 기획과 개발 문서 |

## 코드 수정 전

1. 이 문서를 읽는다.
2. `docs/README.md`를 읽는다.
3. `docs/` 아래에서 대상 기능과 관련된 문서를 읽는다.
4. 수정 대상 코드의 기존 아키텍처와 명명 규칙을 따른다.

프로젝트 문서에 없는 요구사항을 임의로 만들거나 변경하지 않는다. 문서와 코드가 충돌하면 임의로 판단하지 말고 충돌 내용을 보고한다.

구현 후에는 관련 테스트와 정적 검사를 실행한다.

## 공통 규칙

### 주석과 로그

- 변수명과 타입만으로 목적을 알기 어려운 중요한 변수는 주석을 작성한다.
- 함수명과 타입만으로 목적이나 중요한 동작을 알기 어려운 함수에는 주석을 작성한다.
- 로그 메시지에서 코드 식별자(변수명, 메서드명, 클래스명 등)는 영어로 유지하고, 나머지 설명은 한글로 작성한다.

### 공유 모델과 enum

- 여러 코드베이스(`app/`, `server/functions/`, `server/game/`)가 함께 사용하는 Firestore·Realtime Database 문서는 사용하는 쪽마다 모델을 선언하고 필드명, 타입, nullable 여부를 일치시킨다.
- 한쪽에서만 사용하는 문서는 사용하는 쪽에만 모델을 선언한다.
- DB에 저장하는 enum도 같은 기준으로 선언하고 Dart의 `enum.name`과 동일한 문자열을 사용한다.
- 모델은 데이터 구조만 정의하고 비즈니스 로직은 서비스나 함수에서 처리한다.
- 장기 규칙과 관련된 타입(`Position`, `Move`, 기보 표기 등)은 `janggi_core`에 한 번만 정의하고 다른 Dart 코드베이스에서 다시 선언하지 않는다.

### 설정 저장

| 종류 | 위치 |
|---|---|
| 앱과 서버가 같이 쓰는 설정, 운영하면서 바꾸는 설정 | Firestore `configs/app` 문서 |
| 서버만 쓰고 운영 중 바꿀 일이 없는 설정 (예: 외부 API 모델 이름) | `server/functions/src/config.ts` |
| 비밀값 (API 키 등) | Secret Manager |

- `configs/app`은 앱이 로그인 전에도 읽을 수 있게 읽기를 열고, 쓰기는 막는다. Admin 웹은 Callable로 바꾼다.
- `configs/app`의 모델은 앱과 Functions 양쪽에 선언하고 필드를 일치시킨다.
- 알려지면 악용될 수 있는 값(검사 기준값 등)은 `configs/app`에 두지 않는다.
- Functions는 요청마다 `configs/app`을 읽지 않도록 짧은 시간 동안 메모리에 캐시한다.

### 개발 환경

- 개발과 테스트는 Firebase Emulator Suite에 연결해서 한다. 운영 프로젝트에 테스트 계정이나 테스트 데이터를 쓰지 않는다.
- 앱의 개발 빌드는 기본으로 에뮬레이터에 연결한다.

## janggi_core 규칙

이 규칙은 `packages/janggi_core/` 아래 파일에 적용한다.

- Flutter, Firebase, 파일·네트워크 I/O에 의존하지 않는다. 의존성은 순수 Dart 패키지만 허용한다.
- 국면 객체는 불변으로 만든다. 수를 두면 기존 객체를 바꾸지 않고 새 객체를 반환한다.
- 규칙 판정은 앱과 서버가 같은 함수를 호출한다. 한쪽 전용 규칙 분기를 만들지 않는다.
- 규칙을 추가하거나 바꿀 때는 해당 규칙의 테스트를 같은 변경에서 추가한다.
- Fairy-Stockfish(GPL-3)는 perft 비교 등 개발 PC의 검증 도구로만 사용하고, 그 소스나 바이너리를 저장소 코드에 포함하지 않는다.

### janggi_core 검증

`packages/janggi_core/`에서 다음 명령을 실행한다.

```text
dart analyze
dart test
```

## 스크립트

실행 스크립트는 `server/functions/src/scripts/`와 `tools/` 두 곳에 두며 의존 대상으로 나눈다.

- `server/functions/src/scripts/`: Functions 소스나 `firebase-admin`으로 배포된 Firestore·Auth를 다루는 운영 스크립트. `tsc`로 함께 빌드하고 `functions/package.json`의 npm script로 실행하며 나머지 Functions 코드와 같은 규칙과 테스트를 적용한다.
- `tools/`: 어느 코드베이스에도 의존하지 않는 독립 스크립트. 조사, 호환성 테스트, 릴리스 태그가 여기 속한다. 빌드하지 않고 직접 실행한다.

두 곳을 합치지 않는다. 독립 스크립트를 `src` 아래에 두면 배포하지 않는 코드가 Functions 빌드와 배포 번들을 통과한다.

## 커밋과 배포

스토어에 있는 옛 앱이 새 서버를 한동안 함께 쓰므로 서버와 앱은 따로 배포할 수 있어야 한다.

- 서버 변경은 옛 앱이 읽는 계약을 추가로만 바꾼다. 새 Callable·엔드포인트, 새 선택 필드, 기존 값의 계산 방식 변경은 허용한다. 앱이 파싱하는 enum 값 추가, 필수 필드 삭제·이름 변경·null 저장, Callable·엔드포인트 삭제·이름 변경·필수 파라미터 추가는 옛 앱이 더 쓰이지 않을 때까지 하지 않는다.
- 서버 변경 커밋의 메시지 본문에 옛 앱 호환성을 한 줄 적는다. 예: `호환성: 옛 앱 영향 없음` 또는 `호환성: 옛 앱이 읽는 대국 종료 사유 계산 변경, 배포 전 확인 필요`.
- `janggi_core`의 규칙 판정 변경(합법수, 승패·무승부 조건, 점수 계산)은 서버 계약 변경으로 취급한다. 옛 앱의 판정과 새 서버의 판정이 달라지면 옛 앱 사용자의 수가 거절되므로, 커밋 메시지에 호환성 메모를 적고 배포 전에 옛 앱 영향을 확인한다.
- 서버를 먼저 배포하고 앱을 나중에 제출한다.
- 보안 규칙과 Functions는 에뮬레이터에서 확인한 뒤에만 배포한다.

## Flutter 앱 규칙

이 규칙은 `app/` 아래 파일에 적용한다.

### 다국어 지원

- 모든 UI 문자열은 `app/lib/l10n`의 l10n ARB 파일에서 가져온다.
- UI 텍스트를 하드코딩하지 않는다.
- UI 문구를 변경할 때는 한국어와 영어를 포함한 모든 지원 언어의 ARB 파일을 같은 변경에서 함께 수정한다.
- 각 l10n 사용 코드 바로 위에 실제 사용자에게 표시되는 한국어 문구 그대로를 소스 주석으로 추가한다. 개발자를 위한 설명을 적지 않는다.

### 상태와 아키텍처

- 상태 클래스는 Flutter 기본 `ChangeNotifier`를 상속하고 이름을 `<기능>Manager`로 짓는다. Manager는 기능별로 여러 개 만든다. Provider, Riverpod, Bloc 등 서드 파티 상태 관리 패키지를 추가하지 않는다.
- 앱 수명 동안 유지할 Manager는 전역 `AppManagers managers`, Repository는 전역 `AppRepositories repositories` 인스턴스로 관리한다.
- 각 Repository 파일에는 전역 인스턴스를 선언하지 않는다. 기본 Repository의 생성과 의존성 조립은 `AppRepositories.createDefault()`에 모은다.
- 각 Manager 파일에는 전역 인스턴스를 선언하지 않는다. 기본 Manager의 생성과 의존성 조립은 `AppManagers.createDefault()`에 모은다.
- Manager는 Repository를 생성자 매개변수로 받지 않고 `repositories`의 Repository를 직접 사용한다. Manager 사이의 의존성은 생성자 매개변수로 명시한다.
- 앱은 Firebase 초기화 뒤 `repositories`, `managers` 순서로 설정한다. 테스트도 각 테스트의 위젯 또는 대상 코드를 생성하기 전에 같은 순서로 설정한다.
- Screen과 Router는 `managers`의 Manager를 직접 사용하며 Manager를 생성자 매개변수로 전달하지 않는다.
- Manager를 참조하는 Router는 `JanggigoApp` 인스턴스를 생성할 때 함께 생성해 해당 시점에 설정된 `managers`를 사용한다.
- 한 화면이나 한 대국에만 쓰는 상태(예: 장기판 선택 상태)는 `managers`에 등록하지 않고 해당 화면이 생성하고 `dispose()`하는 Manager(예: `BoardManager`)에 둔다.
- 대국 시계처럼 자주 바뀌는 값은 장기판 Manager와 다른 `ValueNotifier`·`ChangeNotifier`로 분리해 그 값을 쓰는 위젯만 다시 그려지게 한다.
- 장기판과 기물은 `CustomPainter`로 그리고 `RepaintBoundary`로 감싼다.
- UI에는 `ListenableBuilder`를 사용하고 부수 효과에는 `addListener`/`removeListener`를 사용한다.
- 실시간 갱신이 필요하지 않은 목록 쿼리에는 `Stream` 대신 `Future`를 사용한다.
- `build()`에서 부수 효과를 발생시키지 않는다. 비동기 작업과 상태 변경은 생명주기 메서드나 이벤트 핸들러에서만 시작한다.
- 클로저 캡처가 필요하지 않은 리스너 등록 및 해제에는 이름이 있는 메서드를 사용한다.
- `build()` 메서드나 빌더 콜백 안에 함수를 정의하지 않는다.
- 기능이 큰 함수는 인라인 비동기 블록과 콜백을 피하고 이름이 있는 메서드로 추출한다.
- `initState`에서는 스트림 리스너의 콜백 본문을 이름이 있는 메서드에 위임한다.

### Repository

- Firestore의 최상위 컬렉션과 하위 컬렉션은 각각 대응하는 repository 파일을 하나씩 둔다. Realtime Database는 최상위 경로마다 repository 파일을 하나씩 둔다.
- 컬렉션·경로 이름, 참조 생성, 조회 조건, 정렬, 제한, cursor와 트랜잭션 읽기·쓰기는 repository 안에 둔다.
- 여러 repository의 공유 상태나 복잡한 비즈니스 흐름은 manager가 조합한다.
- 화면에서만 사용하는 상태의 단순 조회와 액션은 화면이 repository를 직접 호출할 수 있다. 단순 전달만 하는 manager 메서드는 만들지 않는다.
- Callable과 대국 서버 호출은 주요 변경 대상 컬렉션의 repository에 둔다. 주요 컬렉션이 없고 인증 생명주기에 속하는 호출은 `AuthRepository`에 둘 수 있다.
- 여러 컬렉션을 사용하는 작업을 하나의 범용 repository나 비즈니스 동작 이름의 repository로 합치지 않는다.

### 클래스와 모델 구조

- `State` 클래스는 멤버 변수, `initState`, 나머지 오버라이드 메서드, `build()`, 헬퍼 메서드 순서로 작성한다.
- 일반 클래스는 기본적으로 멤버 변수, 생성자, 메서드 순서로 작성한다.
- 생성자와 `dispose()`가 있는 클래스에서는 `dispose()`를 생성자 바로 아래에 둔다.
- 매개변수를 필드에 할당하기만 하는 생성자는 `GameRepository({required this.functions})`와 같은 초기화 형식 매개변수를 사용한다.
- 모델의 JSON 직렬화에는 가능한 경우 수동 Map 파싱 대신 `json_annotation`과 `json_serializable`을 사용한다.
- 모델 클래스에서 어노테이션이 없는 필드는 연속해서 배치하고 어노테이션 블록은 빈 줄로 구분한다. 각 `@JsonKey`는 해당 필드 바로 위에 둔다.

### 액션과 오류 처리

- 액션 메서드는 `void` 또는 `Future<void>`를 반환하고 실패하면 예외를 던진다. 성공 또는 실패를 나타내는 boolean 값을 반환하지 않는다.
- 화면에서 manager 또는 repository 액션을 호출할 때는 `try-catch`로 감싼다.
- 여러 종류의 예외를 같은 방식으로 로그하고 사용자에게 표시할 때는 하나의 `catch`에서 공통 처리한다. 직접 던진 `AppException`이 함께 발생할 수 있으면 `error is AppException`일 때 `getMessage`를 사용하고, 그 외에는 해당 작업의 기본 다국어 오류 메시지를 사용한다. 필요한 경우 예외별 `on` 절을 사용할 수 있다.
- 사용자에게 표시할 오류 메시지는 `AppException` 하나로만 표현한다. 사용자용 메시지 전달을 위한 커스텀 Exception 클래스를 추가하지 않는다.
- 화면까지 전달된 오류는 화면의 `catch`에서만 `error`와 `stackTrace`를 로그에 남기고 다국어 사용자 메시지를 표시한다.
- 다시 던지기만 하는 `catch`는 만들지 않는다. 정리만 필요하면 `finally`를 사용한다.
- 오류를 삼키는 `catch`나 `onError`에서는 그 자리에서 `error`와 `stackTrace`를 로그에 남긴다.
- 커스텀이 적은 다이얼로그에는 `DialogUtils`를 사용하고 기본적으로 제목을 생략한다.
- 사용자 텍스트 입력이 있는 다이얼로그는 닫기 전에 유효성을 검사해 잘못된 입력을 사용자가 수정할 수 있도록 유지한다.

### Flutter 검증

`app/`에서 다음 명령을 실행한다.

```text
flutter gen-l10n
flutter analyze
flutter test
```

변경한 Dart 파일에 새로 하드코딩된 사용자용 문자열이 없는지도 확인한다.

## Dart 공통 스타일

이 규칙은 `app/`, `packages/janggi_core/`, `server/game/`의 Dart 코드에 적용한다.

### 명명과 데이터 의미

- boolean 필드 이름은 `active`, `selected`, `deleted`, `checked`처럼 형용사 형태를 사용한다.
- 이미 상태를 나타내는 boolean 이름에 불필요한 상태 접미사를 추가하지 않는다. `moveSendingActive`보다 `moveSending`을 사용한다.
- boolean을 반환하는 메서드는 `isLegal`, `hasAccess`처럼 `is` 또는 `has` 접두사를 사용한다.
- 단순 조회에는 `resolve*`보다 `get*`을 사용한다. 여러 규칙이나 소스를 아우르는 복잡한 결정에만 `resolve*`를 사용한다.
- extension보다 enum 인스턴스 메서드를 사용한다. 직접 만든 문자열 변환 헬퍼 대신 Dart 기본 enum의 `name`과 `values.byName()`을 사용한다.
- 저장소 메서드 이름은 엔티티별로 일관되게 `create<Entity>`, `update<Entity>`, 단건 조회는 `get<Entity>`, 목록 조회는 `get<Entities>`를 사용한다.
- 스키마, API 또는 UX에서 빈 문자열을 명시적으로 요구하지 않는 한 누락된 선택 데이터에는 인위적인 빈 문자열 대신 `null`을 사용한다.
- null 또는 유효하지 않은 값에 무조건적인 기본값을 사용하지 않는다. 제품 UX나 설정 스키마에서 명시적으로 요구하는 경우에만 기본값을 사용하고, 그 외에는 즉시 실패하거나 오류를 드러내거나 null 상태를 유지한다.
- 로그와 텔레메트리에서는 nullable 값을 `"none"` 같은 대체 문자열로 바꾸지 않고 그대로 유지한다.
- 구체적인 경계 조건이나 데이터 품질 위험이 없다면 사용자 입력이 아닌 시스템, SDK, 저장소 또는 생성 값에 `trim()` 등의 정규화를 적용하지 않는다.

### 포맷과 제어 흐름

- 생성식에서 타입이 명확한 지역 변수는 타입을 중복해서 선언하지 않고 타입 추론을 사용한다. 재할당하지 않는 변수는 `final List<Move> moves = <Move>[];` 대신 `final moves = <Move>[];`로 작성하고, 이후 재할당이 필요한 변수는 억지로 `final`을 사용하지 않고 `var`로 선언한다.
- 조기 반환 조건과 해당 `return`은 서로 다른 줄에 작성한다.
- 단순한 비위젯 할당문과 호출문은 120자 안에 들어가면 한 줄로 작성한다.
- 여러 줄의 점 연결 호출은 한 줄에 호출 하나씩 작성한다.
- 일반 로직에서 중첩 삼항 연산자를 피하고 명시적인 `if` 문을 사용한다.
- `finally`에서 잠금 또는 로딩 상태를 초기화할 때는 상태 활성화를 `try` 블록의 첫 문장에서 수행하고, `finally`에서 초기화한다.
- 위젯 트리는 Flutter UI를 읽기 쉬운 형태로 포맷한다.

## Dart 대국 서버 규칙

이 규칙은 `server/game/` 아래 파일에 적용한다.

- 수의 합법성 판정은 반드시 `janggi_core`를 호출한다. 서버에 별도 규칙 판정 코드를 만들지 않는다.
- 클라이언트가 보낸 수와 시간은 신뢰하지 않는다. 수 검증과 대국 시계는 서버가 기준이다.
- 시간은 `DateTime.now().toUtc()`로 구하고 UTC로 저장한다. 로컬 시간대 변환은 앱의 표시 단계에서만 한다.
- 요청 파라미터 검증은 엔드포인트별 `validateParams()`에 모으고 비즈니스 로직 전에 호출한다.
- DB 접근은 repository에서만 수행한다. repository 규칙은 Firebase 백엔드 규칙과 같다.

## Admin 웹 규칙

이 규칙은 `server/admin/` 아래 파일에 적용한다.

### 상태와 아키텍처

- 라우팅은 React Router, 전역 클라이언트 상태는 Zustand, 스타일은 Tailwind CSS를 사용한다.
- 소스는 TypeScript·TSX와 strict 검사를 사용한다. `.js`, `.jsx` 소스는 추가하지 않는다.
- Firebase Auth claim, Callable 요청·응답, Zustand 상태와 라우트 파라미터에 타입을 선언하며 `any`로 경계를 우회하지 않는다.
- 외부 입력과 Callable 응답은 `unknown`에서 시작해 `services/adminApi` 경계에서 필수 필드와 enum 값을 검증한다.
- 현재 보고 있는 신고와 사용자의 식별자는 URL을 원본으로 사용하고 같은 값을 Zustand에 별도로 복제하지 않는다.
- 인증 상태와 claim 확인은 `authStore`, 신고·조치 상태는 `moderationStore`, 서버 원본이 아닌 화면 상태는 `uiStore`에서 관리한다.
- Firebase 초기화와 Callable 호출은 `services` 아래에 두고 화면 컴포넌트에서 Firebase SDK를 직접 호출하지 않는다.
- 신고 원문, 채팅 내용과 사용자 비공개 정보를 Zustand persist, `localStorage` 또는 기타 장기 브라우저 저장소에 보관하지 않는다.

### 권한과 데이터 접근

- 보호 라우트는 Firebase Auth 복원과 ID token의 `admin: true` claim 확인이 끝난 뒤에만 렌더링한다.
- 클라이언트 claim 확인만 신뢰하지 않고 모든 Admin 조회와 변경을 claim을 재검증하는 Callable을 통해 수행한다.
- Admin 웹의 직접 접근을 위해 신고, 제재 기록, 사용자 비공개 컬렉션의 보안 규칙을 열지 않는다.
- 서비스 계정, Admin SDK credential과 ID token을 소스, 브라우저 번들, 로그 또는 Hosting 결과에 포함하지 않는다.
- 운영 조치는 사유 입력과 확인 단계를 거치며 요청 중 중복 제출을 막는다. 성공 뒤 관련 목록과 상세 상태를 서버 응답으로 갱신한다.
- 오류 로그에는 신고·채팅 원문, 이메일, token과 전체 Callable payload를 남기지 않는다.

### UI

- 처리 상태와 제재 상태는 색상만으로 표현하지 않고 텍스트 또는 아이콘 레이블을 함께 사용한다.
- 로딩, 빈 데이터, 권한 없음, 재시도 가능한 오류와 완료 상태를 구분해 표시한다.
- 계정 상태를 바꾸는 조치는 대상, 종류, 기간과 연결된 신고를 실행 직전에 다시 보여준다.

### Admin 웹 검증

`server/`에서 다음 명령을 실행한다.

```text
npm --prefix admin run lint
npm --prefix admin run build
```

인증·Callable·신고 처리 계약을 바꿨다면 일반 사용자 거부, Admin 허용, 중복 조치를 Emulator 또는 Functions 테스트로 함께 검증한다.

## Firebase 백엔드 규칙

이 규칙은 `server/functions/`, Firebase 보안 규칙과 Firebase 설정 파일에 적용한다.

### Repository

- Functions의 런타임 Firestore·Realtime Database 접근은 `server/functions/src/repositories` 아래에서만 수행한다.
- Firestore의 최상위 컬렉션과 하위 컬렉션은 각각 대응하는 repository 파일을 하나씩 둔다.
- 컬렉션 이름, 문서 참조 생성, 조회 조건, 정렬, 제한, cursor와 트랜잭션 읽기·쓰기는 repository 안에 둔다.
- callable과 service는 repository를 조합해 비즈니스 흐름과 트랜잭션 순서를 관리하고 컬렉션을 직접 참조하지 않는다.
- 여러 컬렉션을 사용하는 작업을 하나의 범용 repository나 비즈니스 동작 이름의 repository로 합치지 않는다.
- Emulator 통합 테스트의 fixture 준비와 저장 결과 검증을 위한 직접 접근은 `server/functions/test` 아래에서만 허용한다.

### 보안 규칙

- Firestore와 Realtime Database 보안 규칙은 기본 거부에서 시작하고 필요한 경로만 연다.
- 대국 상태(수, 시계, 결과, 급수 변동)는 서버(`server/game`, Functions의 Admin SDK)만 쓴다. 클라이언트에는 쓰기 권한을 주지 않는다.
- 관전용 진행 중 대국 데이터는 비로그인 읽기를 허용한다. 채팅과 대국 참여는 로그인한 사용자만 허용한다.
- 보안 규칙을 바꾸면 허용되어야 할 접근과 거부되어야 할 접근을 에뮬레이터 테스트로 함께 검증한다.

### Callable과 검증

- Callable 요청 파라미터는 해당 함수 파일에 `interface`로 선언해 타입을 검사한다.
- callable 핸들러에서는 먼저 `const requestParams = request.data;`와 같이 `request.data`를 지역 변수에 할당하고 모든 payload 필드를 해당 변수에서 읽는다.
- payload 타입, enum, 길이와 형식 검증은 해당 함수 파일의 `validateParams()`에 모으고 핸들러의 비즈니스 로직 전에 호출한다.
- 호출자 `uid`처럼 검증에 필요한 문맥이 있으면 `validateParams(requestParams, uid)`와 같이 명시적으로 전달한다.
- payload가 없는 callable에는 불필요한 `validateParams()`를 만들지 않는다.

### 외부 API

- OpenAI 등 외부 API 키는 Functions의 Secret Manager 설정으로만 관리하고 소스, 앱, Admin 웹 번들에 넣지 않는다.
- 외부 API 호출은 서버에서만 한다. 앱과 Admin 웹이 외부 API를 직접 호출하지 않는다.

### 설정, 리전, 날짜·시간

- 모든 Functions는 리전을 `asia-northeast3`(서울)로 명시한다. 기본 리전(`us-central1`)에 배포되지 않게 한다.
- 서버 측 날짜·시간 계산에는 `Date()` 또는 `Date.now()`보다 `dayjs`를 우선 사용한다.
- `config.ts`에 설정을 추가할 때는 설정 키 바로 위에 해당 설정을 설명하는 한국어 주석을 작성한다.

### 정적 검사

- ESLint에는 버그를 잡는 규칙(처리되지 않은 Promise, 사용하지 않는 변수, 타입 오류 등)만 둔다. 공백, 따옴표, 줄 길이 같은 스타일 규칙은 끄고 Prettier가 자동으로 포맷한다.
- 배포 전 lint는 유지한다.

### 명명과 제어 흐름

- 기존 TypeScript 아키텍처와 명명 규칙을 따른다.
- 백엔드 로직에서 `a ? b : (c ? d : e)`와 같은 중첩 삼항 연산자를 사용하지 않고 명시적인 `if` 문을 사용한다.
- 반복문으로 표현할 수 있는 경우 `forEach`보다 `for`, `for...in`, `for...of`를 우선 사용한다.

### 로깅

- 모든 Functions 작업 흐름에는 정상 처리가 Firebase Console에 드러나도록 간결한 `logger.info(...)` 성공 로그를 하나 이상 남긴다.
- 진단이 필요한 주요 중간 지점에는 `logger.debug(...)` 로그를 남긴다. 큰 payload 전체를 출력하지 않고 식별자와 상태 필드 위주로 간결하게 작성한다.

### Firebase 백엔드 검증

`server/functions/`에서 다음 명령을 실행한다.

```text
npm run lint
npm run build
npm test
```

## DB 명명

이 규칙은 Firestore 컬렉션과 Realtime Database 경로에 적용한다.

- 여러 최상위 컬렉션이 같은 리소스의 변형인 경우에만 공통 접두사를 사용한다.
- 공통 접두사가 필요하면 동일한 복수형을 일관되게 사용한다. `games_active`와 `games_archived`를 사용하고 `games_`와 `game_`을 섞지 않는다.
- 중첩 하위 컬렉션은 상위 컬렉션 이름을 반복하지 않는다. `games/{id}/games_moves`가 아니라 `games/{id}/moves`를 사용한다.
- boolean 필드는 `active`, `deleted`, `rated` 같은 형용사 이름을 사용한다. `is*`와 `has*`는 boolean을 반환하는 메서드에만 사용한다.
