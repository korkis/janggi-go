/// 앱 언어 설정(`docs/screens.md`의 설정). 기기에만 저장하고 값은 `name`이다.
enum AppLanguage {
  /// 기기 언어를 따른다(기본). 지원하지 않는 언어면 Flutter 기본 규칙으로 고른다.
  system,
  ko,
  en,
}
