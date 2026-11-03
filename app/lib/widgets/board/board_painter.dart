import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:janggi_core/janggi_core.dart';

import 'board_geometry.dart';

/// 판 배경과 선, 궁성 대각선, 포·졸 자리 표시를 그린다. 기물이 움직여도 다시 그리지 않는다.
///
/// 판은 위아래·좌우 대칭이므로 판 돌리기와 상관없이 같은 그림이다.
class BoardPainter extends CustomPainter {
  static const _lineColor = Color(0xC746280F);

  /// 선 굵기(칸 크기의 배수).
  static const _lineWidthCells = 0.026;

  /// 포·졸 자리 × 표시의 폭(칸 크기의 배수). 교차점을 가운데로 한다(`docs/ui.md`의 색과 구분).
  static const _markWidthCells = 1 / 6;

  /// 화면 기준 (열, 행)의 포 자리와 졸·병 자리.
  static const _markPoints = [
    (1, 2), (7, 2), (1, 7), (7, 7), //
    (0, 3), (2, 3), (4, 3), (6, 3), (8, 3), //
    (0, 6), (2, 6), (4, 6), (6, 6), (8, 6),
  ];

  /// 판 배경 그림. 아직 읽지 않았으면 선만 그린다.
  final ui.Image? background;

  const BoardPainter({required this.background});

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = BoardGeometry(size, flipped: false);
    final background = this.background;
    if (background != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: background,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    }
    final linePaint = Paint()
      ..color = _lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, geometry.cell * _lineWidthCells);
    _paintGrid(canvas, geometry, linePaint);
    _paintPalaces(canvas, geometry, linePaint);
    _paintMarks(canvas, geometry, linePaint);
  }

  void _paintGrid(Canvas canvas, BoardGeometry geometry, Paint paint) {
    const lastColumn = Square.fileCount - 1;
    const lastRow = Square.rankCount - 1;
    for (var row = 0; row <= lastRow; row++) {
      canvas.drawLine(geometry.pointAt(0, row), geometry.pointAt(lastColumn, row), paint);
    }
    for (var column = 0; column <= lastColumn; column++) {
      canvas.drawLine(geometry.pointAt(column, 0), geometry.pointAt(column, lastRow), paint);
    }
  }

  void _paintPalaces(Canvas canvas, BoardGeometry geometry, Paint paint) {
    for (final top in [0, Square.rankCount - 3]) {
      canvas.drawLine(geometry.pointAt(3, top), geometry.pointAt(5, top + 2), paint);
      canvas.drawLine(geometry.pointAt(5, top), geometry.pointAt(3, top + 2), paint);
    }
  }

  /// 교차점을 가운데로 하는 작은 ×를 선과 같은 색·굵기로 끊김 없이 긋는다. 판 가장자리 줄도 같은 모양이다.
  void _paintMarks(Canvas canvas, BoardGeometry geometry, Paint paint) {
    final half = geometry.cell * _markWidthCells / 2;
    final path = Path();
    for (final (column, row) in _markPoints) {
      final center = geometry.pointAt(column, row);
      path
        ..moveTo(center.dx - half, center.dy - half)
        ..lineTo(center.dx + half, center.dy + half)
        ..moveTo(center.dx - half, center.dy + half)
        ..lineTo(center.dx + half, center.dy - half);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => oldDelegate.background != background;
}
