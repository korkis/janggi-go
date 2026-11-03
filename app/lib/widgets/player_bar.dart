import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 대국 화면 위·아래의 정보 줄. 진영 표시, 이름, 그 아래 한 줄, 오른쪽 표시를 둔다.
///
/// 차례인 쪽([active])은 진영 표시 둘레를 강조색으로 두르고 이름을 밝게 한다.
class PlayerBar extends StatelessWidget {
  static const _avatarSize = 44.0;

  final Side side;
  final bool active;

  /// 이름 자리에 보여줄 글자(온라인 대국의 닉네임과 급수). 없으면 진영 이름을 보여준다.
  final String? name;

  /// 이름 아래 한 줄. 없으면 이름만 보여준다.
  final String? detail;

  /// 오른쪽에 붙는 표시(한수쉼, 시계 등).
  final List<Widget> trailing;

  const PlayerBar({
    super.key,
    required this.side,
    required this.active,
    this.name,
    this.detail,
    this.trailing = const [],
  });

  /// 정보 줄 높이의 넉넉한 어림값. 시계가 있는 줄 기준이다.
  ///
  /// 넓은 화면에서 정보 줄을 판과 같은 폭으로 놓을 때 판 크기를 먼저 정하는 데 쓴다. 실제보다 크게 잡으면 판이 정보 줄 폭에
  /// 딱 맞고 위아래만 조금 남는다.
  static double getEstimatedHeight(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return textScaler.scale(AppTextSizes.large) * 1.35 + textScaler.scale(AppTextSizes.body) * 1.5 + 16;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = this.detail;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SideAvatar(side: side, size: _avatarSize, active: active),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // 한 / 초
                  name ?? l10n.sideName(side.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTextSizes.body,
                    fontWeight: FontWeight.w700,
                    color: active ? GameColors.text : GameColors.subText,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail,
                    style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
                  ),
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// 정보 줄 오른쪽에 붙는 작은 표시.
class PlayerBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final Widget? leading;

  const PlayerBadge({
    super.key,
    required this.label,
    required this.color,
    this.background = GameColors.surface,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// 대국 시계. 큰 글자로 남은 기본 시간(초읽기 중이면 이번 초읽기의 남은 시간), 작은 글자로 남은 초읽기 횟수를 보여준다.
///
/// 시계 값은 자주 바뀌므로 정보 줄과 따로 다시 그린다.
class ClockBadge extends StatelessWidget {
  final String time;
  final String periods;

  /// 초읽기 중이면 글자를 경고색으로 바꾼다.
  final bool warning;

  /// 시계가 흐르는 쪽(차례인 쪽)이면 바탕을 밝게 한다.
  final bool running;

  const ClockBadge({
    super.key,
    required this.time,
    required this.periods,
    required this.warning,
    required this.running,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? GameColors.check : GameColors.text;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: running ? GameColors.accentSurface : GameColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: AppTextSizes.large,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            periods,
            style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
          ),
        ],
      ),
    );
  }
}

/// 진영 한자(楚/漢)를 쓴 동그라미. 차례인 쪽([active])은 둘레를 강조색으로 두른다.
class SideAvatar extends StatelessWidget {
  final Side side;
  final double size;
  final bool active;

  const SideAvatar({super.key, required this.side, required this.size, this.active = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: side == Side.han ? GameColors.hanAvatar : GameColors.choAvatar,
        border: Border.all(color: active ? GameColors.accent : Colors.transparent, width: 2.5),
      ),
      child: Text(
        // 漢 / 楚
        l10n.sideHanja(side.name),
        // 동그라미 크기가 고정이라 글자 크기 설정을 따르지 않는다.
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
          color: side == Side.han ? GameColors.hanAvatarText : GameColors.choAvatarText,
        ),
      ),
    );
  }
}
