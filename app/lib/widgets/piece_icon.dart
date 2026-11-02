import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import 'board/board_images.dart';

/// 판 밖에서 쓰는 기물 그림. 상차림 버튼 등에 쓴다.
class PieceIcon extends StatelessWidget {
  final Piece piece;
  final double size;
  final PieceMaterial material;

  const PieceIcon({super.key, required this.piece, required this.size, this.material = PieceMaterial.plastic});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BoardImages.getPieceAsset(material, piece),
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}
