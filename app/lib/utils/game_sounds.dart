/// 대국 효과음(`docs/ui.md`의 연출). 효과음 파일이 아직 없어 자리만 둔다. 파일이 생기면 여기서 소리를 내고, 설정의 소리 끄기를
/// 따르게 한다.
abstract final class GameSounds {
  /// 장군을 걸거나 받았을 때.
  static void playCheck() {}

  /// 대국이 끝나 결과 도장을 찍을 때.
  static void playResult() {}
}
