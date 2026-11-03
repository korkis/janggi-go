import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../models/spectate_list_entry.dart';
import '../theme/app_theme.dart';
import '../utils/rank_format.dart';
import 'board/board_view.dart';
import 'player_bar.dart';
import 'room_condition_chips.dart';

/// 관전 목록의 카드 하나(`docs/screens.md`의 관전 목록). 판 미리보기, 관전자 수, 접장기 표시, 양쪽 닉네임과 급수, 몇 수째인지를
/// 둔다. 마우스를 올리면 살짝 떠오른다(`docs/ui.md`의 넓은 화면).
class SpectateCard extends StatefulWidget {
  final SpectateListEntry entry;
  final VoidCallback onTap;

  const SpectateCard({super.key, required this.entry, required this.onTap});

  @override
  State<SpectateCard> createState() => _SpectateCardState();
}

class _SpectateCardState extends State<SpectateCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entry = widget.entry;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 120),
      offset: _hovered ? const Offset(0, -0.01) : Offset.zero,
      child: Card(
        elevation: _hovered ? 6 : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: _onHover,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    IgnorePointer(child: BoardView(position: Position.fromFen(entry.fen))),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _OverlayBadge(
                        icon: Icons.visibility_outlined,
                        // 12명
                        label: l10n.spectatorCount(entry.spectatorCount),
                      ),
                    ),
                    if (entry.handicapped)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: ConditionChip(
                          // 접장기
                          label: l10n.roomChipHandicap,
                          color: LightColors.handicap,
                          background: LightColors.handicapSurface,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _PlayerLine(side: Side.han, player: entry.players.han),
                const SizedBox(height: 6),
                _PlayerLine(side: Side.cho, player: entry.players.cho),
                const SizedBox(height: 6),
                Text(
                  // 42수째
                  l10n.spectateMoveCount(entry.moveCount),
                  style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onHover(bool hovered) {
    setState(() {
      _hovered = hovered;
    });
  }
}

class _PlayerLine extends StatelessWidget {
  final Side side;
  final SpectatePlayer player;

  const _PlayerLine({required this.side, required this.player});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        SideAvatar(side: side, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            // {nickname} · {rank}
            l10n.playerNameWithRank(player.nickname, getRankLabel(l10n, player.rankLevel)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// 판 미리보기 위에 얹는 어두운 표시.
class _OverlayBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OverlayBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 관전 카드를 두 줄 바둑판식으로 놓는다(`docs/screens.md`의 관전 목록). 관전 목록, 홈, 대국실이 같이 쓴다.
class SpectateCardGrid extends StatelessWidget {
  final List<({String gameId, SpectateListEntry entry})> entries;
  final ValueChanged<String> onOpen;

  const SpectateCardGrid({super.key, required this.entries, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildCard(entries[i])),
                const SizedBox(width: 12),
                Expanded(child: i + 1 < entries.length ? _buildCard(entries[i + 1]) : const SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCard(({String gameId, SpectateListEntry entry}) item) {
    return SpectateCard(entry: item.entry, onTap: () => onOpen(item.gameId));
  }
}
