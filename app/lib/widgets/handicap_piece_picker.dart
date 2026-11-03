import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/room_format.dart';
import 'piece_icon.dart';

/// 접장기의 뗄 기물 고르기(`docs/screens.md`의 방 만들기). 방 만들기와 대국 신청 보내기가 같이 쓴다.
///
/// 차·마·상·상·마·차와 그 아래 포 두 개를 판에 놓이는 순서대로 늘어놓고, 아래에 고른 결과를 한 줄로 요약한다. 떼는 쪽이 한이므로
/// 한의 기물 그림을 쓴다.
class HandicapPiecePicker extends StatelessWidget {
  /// 뗄 기물의 윗줄. 떼는 쪽이 자기 쪽에서 판을 볼 때 놓이는 순서(차·마·상·상·마·차)다.
  static const _backRowPieces = [
    HandicapPiece.leftChariot,
    HandicapPiece.leftHorse,
    HandicapPiece.leftElephant,
    HandicapPiece.rightElephant,
    HandicapPiece.rightHorse,
    HandicapPiece.rightChariot,
  ];

  /// 뗄 기물의 아랫줄. 포 두 개.
  static const _cannonPieces = [HandicapPiece.leftCannon, HandicapPiece.rightCannon];

  static const _pieceSize = 44.0;

  final Set<HandicapPiece> selected;
  final ValueChanged<HandicapPiece> onToggled;

  const HandicapPiecePicker({super.key, required this.selected, required this.onToggled});

  /// [pieces]를 판에 놓이는 순서대로. 서버에 보낼 때 쓴다.
  static List<HandicapPiece> getOrderedPieces(Set<HandicapPiece> pieces) => [
    for (final piece in [..._backRowPieces, ..._cannonPieces])
      if (pieces.contains(piece)) piece,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPieceRow(_backRowPieces),
        const SizedBox(height: 8),
        _buildPieceRow(_cannonPieces),
        const SizedBox(height: 12),
        Text(
          // 차, 포 떼기 · 20점 적게 시작 / 뗄 기물을 골라 주세요
          selected.isEmpty ? l10n.createRoomPiecesHint : getHandicapSummary(l10n, getOrderedPieces(selected)),
          style: TextStyle(
            fontSize: AppTextSizes.body,
            fontWeight: FontWeight.w700,
            color: selected.isEmpty ? LightColors.subText : LightColors.handicap,
          ),
        ),
      ],
    );
  }

  Widget _buildPieceRow(List<HandicapPiece> pieces) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final piece in pieces)
          _HandicapPieceButton(
            piece: piece,
            size: _pieceSize,
            selected: selected.contains(piece),
            onPressed: () => onToggled(piece),
          ),
      ],
    );
  }
}

/// 뗄 기물 하나. 고르면 회색과 X 표시로 바뀐다(`docs/game/handicap.md`).
class _HandicapPieceButton extends StatelessWidget {
  final HandicapPiece piece;
  final double size;
  final bool selected;
  final VoidCallback onPressed;

  const _HandicapPieceButton({
    required this.piece,
    required this.size,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      // 왼쪽 차 / 오른쪽 포
      label: l10n.handicapPieceLabel(l10n.boardSideName(piece.side.name), l10n.pieceName(piece.type.name)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: selected ? 0.35 : 1,
                child: ColorFiltered(
                  colorFilter: selected
                      ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: PieceIcon(piece: Piece(Side.han, piece.type), size: size),
                ),
              ),
              if (selected) Icon(Icons.close, size: size * 0.8, color: LightColors.handicap),
            ],
          ),
        ),
      ),
    );
  }
}
