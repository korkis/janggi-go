// 대국 서버만 쓰는 설정이다(`docs/dev_rules.md`의 설정 저장). 바꾸려면 다시 배포한다.

/// `configs/app` 문서를 메모리에 캐시하는 시간. 요청마다 Firestore를 읽지 않기 위해서다. Functions와 같다.
const appConfigCacheDuration = Duration(seconds: 60);
