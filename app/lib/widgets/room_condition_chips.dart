import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/room_format.dart';

/// 방 조건 칩. 접장기(다른 색), 진영, 공개 여부, 들어올 수 있는 급수(`docs/screens.md`의 방 대기실, 대국실).
///
/// 방 목록에는 공개 방만 있으므로 [showListed]를 끄고 공개 여부를 빼고 보여준다.
class RoomConditionChips extends StatelessWidget {
  final Room room;
  final bool showListed;

  const RoomConditionChips({super.key, required this.room, this.showListed = true});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final handicap = room.handicap;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (handicap != null) ...[
          _Chip(
            // 접장기
            label: l10n.roomChipHandicap,
            color: LightColors.handicap,
            background: LightColors.handicapSurface,
          ),
          _Chip(
            // 방장이 떼요 / 상대가 떼요
            label: l10n.roomChipRemover(handicap.remover.name),
            color: LightColors.handicap,
            background: LightColors.handicapSurface,
          ),
        ] else
          _Chip(
            // 방장 초 / 방장 한 / 진영 무작위
            label: l10n.roomChipSide(room.hostSide.name),
          ),
        if (showListed)
          _Chip(
            // 공개 / 비공개
            label: room.listed ? l10n.roomChipListed : l10n.roomChipUnlisted,
          ),
        if (room.listed) _Chip(label: getRankRangeLabel(l10n, room.rankRange)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _Chip({required this.label, this.color = LightColors.accent, this.background = LightColors.accentSurface});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
