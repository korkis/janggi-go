import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:janggi_core/janggi_core.dart';

import 'board_geometry.dart';
import 'board_images.dart';

/// 기물과 판 위 표시(고른 기물, 갈 수 있는 자리, 방금 둔 수, 차례)를 그린다.
///
/// 크기와 색은 `docs/ui.md`의 "판 위 표시"와 시안을 따르고, 길이는 칸 크기 기준이다.
class PiecesPainter extends CustomPainter {
  /// 기물 그림 한 변(칸 크기의 배수). 궁·차·사 등의 크기 차이는 그림 안에 들어 있다.
  static const _pieceCells = 1.05;

  /// 고른 기물을 들어 올리는 높이와 키우는 배율.
  static const _liftCells = 0.12;
  static const _liftScale = 1.09;

  /// 갈 수 있는 자리 표시의 호 반지름, 굵기, 호 하나가 차지하는 각도.
  static const _markRadiusCells = 0.38;
  static const _markWidthCells = 0.062;
  static const _markSweep = math.pi / 6;
  static const _markColor = Color(0xFFFFE6A8);
  static const _markShadowColor = Color(0x996E3E0A);
  static const _markGlowColor = Color(0xA6FFCD6E);

  static const _shadowColor = Color(0x73281400);
  static const _liftedShadowColor = Color(0x611E0F00);

  /// 방금 둔 기물의 금빛 번짐. (색, 번짐 정도(칸 크기의 배수)) 순서로 안쪽부터 겹쳐 그린다.
  static const _lastMoveGlows = [
    (Color(0xFFFFEEAF), 0.036),
    (Color(0xFFFFD064), 0.083),
    (Color(0xCCFFC350), 0.143),
    (Color(0x99FFB946), 0.215),
  ];

  /// 상차림에서 바뀌는 자리의 옅은 금빛.
  static const _highlightGlow = (Color(0xE6FFD678), 0.04);

  /// 상대 차례에 내 기물을 어둡게 하는 정도.
  static final _dimFilter = ColorFilter.matrix(_brightnessSaturationMatrix(0.93, 0.94));
  static final _lastMoveFilter = ColorFilter.matrix(_brightnessSaturationMatrix(1.06, 1));

  final BoardImages? images;
  final Position position;
  final bool flipped;
  final Square? selected;

  /// 고른 기물이 갈 수 있는 자리. 빈 자리와 잡을 수 있는 자리를 같은 표시로 그린다.
  final Set<Square> targets;

  /// 마지막으로 둔 수. 한수쉼이면 표시하지 않는다.
  final Move? lastMove;

  /// 기물을 살짝 어둡게 그릴 진영. 차례가 아닌 쪽이다.
  final Side? dimmedSide;

  /// 상차림에서 금빛으로 살짝 표시할 자리.
  final Set<Square> highlighted;

  /// [lastMove]의 이동 애니메이션 진행도(0~1). 1이면 이동이 끝난 상태로 그린다.
  final Animation<double> moveProgress;

  /// [lastMove]로 잡힌 기물. 이동 애니메이션 동안 도착 칸에 남겨 그린다.
  final Piece? captured;

  PiecesPainter({
    required this.images,
    required this.position,
    required this.flipped,
    required this.selected,
    required this.targets,
    required this.lastMove,
    required this.dimmedSide,
    required this.highlighted,
    required this.moveProgress,
    required this.captured,
  }) : super(repaint: moveProgress);

  @override
  void paint(Canvas canvas, Size size) {
    final images = this.images;
    if (images == null) {
      return;
    }
    final geometry = BoardGeometry(size, flipped: flipped);
    final cell = geometry.cell;
    final pieceSize = cell * _pieceCells;
    final progress = Curves.easeOutCubic.transform(moveProgress.value);
    final moving = progress < 1 ? lastMove : null;
    final settledMove = progress < 1 ? null : lastMove;

    // 판에 놓인 기물. 이동 중인 기물은 맨 위에 오도록 마지막에 넣는다.
    final placed = <_PlacedPiece>[];
    _PlacedPiece? justMoved;
    final glowing = <_PlacedPiece>[];
    for (final MapEntry(key: square, value: piece) in position.pieces.entries) {
      if (square == selected || (moving != null && square == moving.to)) {
        continue;
      }
      final isJustMoved = settledMove != null && square == settledMove.to;
      final item = _PlacedPiece(
        images.pieces[piece]!,
        Rect.fromCenter(center: geometry.centerOf(square), width: pieceSize, height: pieceSize),
        _toneFilter(piece, justMoved: isJustMoved),
      );
      placed.add(item);
      if (isJustMoved) {
        justMoved = item;
      } else if (highlighted.contains(square)) {
        glowing.add(item);
      }
    }
    if (moving != null) {
      final to = geometry.centerOf(moving.to!);
      final captured = this.captured;
      if (captured != null) {
        placed.add(
          _PlacedPiece(
            images.pieces[captured]!,
            Rect.fromCenter(center: to, width: pieceSize, height: pieceSize),
            _toneFilter(captured, justMoved: false),
          ),
        );
      }
      final piece = position.pieceAt(moving.to!);
      if (piece != null) {
        final center = Offset.lerp(geometry.centerOf(moving.from!), to, progress)!;
        placed.add(
          _PlacedPiece(
            images.pieces[piece]!,
            Rect.fromCenter(center: center, width: pieceSize, height: pieceSize),
            _toneFilter(piece, justMoved: false),
          ),
        );
      }
    }

    _paintSilhouettes(canvas, size, placed, _shadowColor, cell * 0.018, Offset(0, cell * 0.048));
    final glowSource = justMoved;
    if (glowSource != null) {
      for (final (color, spread) in _lastMoveGlows) {
        _paintSilhouettes(canvas, size, [glowSource], color, cell * spread, Offset.zero);
      }
    }
    if (glowing.isNotEmpty) {
      final (color, spread) = _highlightGlow;
      _paintSilhouettes(canvas, size, glowing, color, cell * spread, Offset.zero);
    }
    for (final item in placed) {
      _paintPiece(canvas, item);
    }

    final selectedSquare = selected;
    final selectedPiece = selectedSquare == null ? null : position.pieceAt(selectedSquare);
    if (selectedSquare != null && selectedPiece != null) {
      final liftedSize = pieceSize * _liftScale;
      final center = geometry.centerOf(selectedSquare).translate(0, -cell * _liftCells);
      final lifted = _PlacedPiece(
        images.pieces[selectedPiece]!,
        Rect.fromCenter(center: center, width: liftedSize, height: liftedSize),
        null,
      );
      _paintSilhouettes(canvas, size, [lifted], _liftedShadowColor, cell * 0.072, Offset(0, cell * 0.19 * _liftScale));
      _paintPiece(canvas, lifted);
    }

    _paintTargets(canvas, geometry);
  }

  ColorFilter? _toneFilter(Piece piece, {required bool justMoved}) {
    if (justMoved) {
      return _lastMoveFilter;
    }
    if (piece.side == dimmedSide) {
      return _dimFilter;
    }
    return null;
  }

  /// 갈 수 있는 자리마다 교차점 둘레 네 귀(대각선 방향)에 짧은 호를 그린다.
  void _paintTargets(Canvas canvas, BoardGeometry geometry) {
    if (targets.isEmpty) {
      return;
    }
    final radius = geometry.cell * _markRadiusCells;
    final path = Path();
    for (final square in targets) {
      final rect = Rect.fromCircle(center: geometry.centerOf(square), radius: radius);
      for (var corner = 0; corner < 4; corner++) {
        final middle = math.pi / 4 + corner * math.pi / 2;
        path.addArc(rect, middle - _markSweep / 2, _markSweep);
      }
    }
    canvas
      ..drawPath(path, _markPaint(geometry.cell, _markShadowColor, 0.018))
      ..drawPath(path, _markPaint(geometry.cell, _markGlowColor, 0.048))
      ..drawPath(path, _markPaint(geometry.cell, _markColor, 0));
  }

  Paint _markPaint(double cell, Color color, double blurCells) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * _markWidthCells
      ..strokeCap = StrokeCap.round;
    if (blurCells > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, cell * blurCells);
    }
    return paint;
  }

  void _paintPiece(Canvas canvas, _PlacedPiece item) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final tone = item.tone;
    if (tone != null) {
      paint.colorFilter = tone;
    }
    canvas.drawImageRect(item.image, _imageRect(item.image), item.rect, paint);
  }

  /// [items]의 기물 모양을 [color] 한 가지 색으로 [sigma]만큼 번지게 [offset]만큼 옮겨 그린다.
  ///
  /// 그림자와 빛은 이미지에 넣지 않고 기물 모양을 따라 코드로 그린다. 웹에서도 번지게 하려고
  /// 이미지 하나마다 필터를 거는 대신 레이어 하나에 모아 그린 뒤 필터를 건다.
  void _paintSilhouettes(Canvas canvas, Size size, List<_PlacedPiece> items, Color color, double sigma, Offset offset) {
    final layerPaint = Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn)
      ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
    canvas.saveLayer(Offset.zero & size, layerPaint);
    final paint = Paint()..filterQuality = FilterQuality.low;
    for (final item in items) {
      canvas.drawImageRect(item.image, _imageRect(item.image), item.rect.shift(offset), paint);
    }
    canvas.restore();
  }

  Rect _imageRect(ui.Image image) => Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

  @override
  bool shouldRepaint(PiecesPainter oldDelegate) =>
      oldDelegate.images != images ||
      oldDelegate.position != position ||
      oldDelegate.flipped != flipped ||
      oldDelegate.selected != selected ||
      !_setEquals(oldDelegate.targets, targets) ||
      oldDelegate.lastMove != lastMove ||
      oldDelegate.dimmedSide != dimmedSide ||
      !_setEquals(oldDelegate.highlighted, highlighted) ||
      oldDelegate.moveProgress != moveProgress ||
      oldDelegate.captured != captured;
}

bool _setEquals<T>(Set<T> a, Set<T> b) => identical(a, b) || (a.length == b.length && a.containsAll(b));

/// CSS의 `brightness()`와 `saturate()`를 차례로 적용한 색 행렬.
List<double> _brightnessSaturationMatrix(double brightness, double saturation) {
  final s = saturation;
  final rows = [
    [0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s],
    [0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s],
    [0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s],
  ];
  return [
    for (final row in rows) ...[for (final value in row) value * brightness, 0, 0],
    0,
    0,
    0,
    1,
    0,
  ];
}

/// 판 위 한 자리에 그릴 기물 그림과 그 위치, 밝기 조정.
final class _PlacedPiece {
  final ui.Image image;
  final Rect rect;
  final ColorFilter? tone;

  const _PlacedPiece(this.image, this.rect, this.tone);
}
