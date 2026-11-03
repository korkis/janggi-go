import '../l10n/app_localizations.dart';
import '../models/active_game.dart';

// 대국 조건을 글자로 바꾼다. 넓은 화면의 대국 화면과 상차림 화면 오른쪽 패널이 같이 쓴다.

/// 대국 종류, 급수 대국 여부, 시간 규칙. "빠른 대국", "급수 대국", "기본 10분 · 초읽기 30초 3회".
List<String> getGameDetails(AppLocalizations l10n, GameMeta meta) {
  final mode = meta.mode;
  final timeControl = meta.timeControl;
  return [
    // 빠른 대국 / 방 대국 / 신청 대국
    if (mode != null) l10n.gameModeName(mode.name),
    // 급수 대국
    if (meta.rated) l10n.gameRated,
    // 기본 10분 · 초읽기 30초 3회
    l10n.gameTimeRule(
      timeControl.baseMs ~/ Duration.millisecondsPerMinute,
      timeControl.periodMs ~/ Duration.millisecondsPerSecond,
      timeControl.periods,
    ),
  ];
}
