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

  /// 이름 아래 한 줄. 없으면 이름만 보여준다.
  final String? detail;

  /// 오른쪽에 붙는 표시(장군, 정했어요 등).
  final List<Widget> trailing;

  const PlayerBar({super.key, required this.side, required this.active, this.detail, this.trailing = const []});

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
                  l10n.sideName(side.name),
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
