/// 지금 시각을 UTC로 돌려준다. 테스트에서 시각을 고정하려고 함수로 받는다.
typedef Clock = DateTime Function();

/// 서버 시각. 시간은 UTC로 구하고 저장한다(`docs/dev_rules.md`의 Dart 대국 서버 규칙).
DateTime utcNow() => DateTime.now().toUtc();
