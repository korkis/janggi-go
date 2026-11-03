import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../../theme/app_theme.dart';
import 'board_geometry.dart';

/// 장군을 건 기물에서 [side]의 궁까지의 공격 길. 길마다 지나는 교차점을 차례로 담는다(`docs/ui.md`의 연출).
///
/// 마·상은 꺾이는 길 그대로 담고(마는 한 칸 곧게 간 뒤 대각선, 상은 한 칸 곧게 간 뒤 대각선 두 칸), 나머지 기물은 기물과 궁을
/// 곧게 잇는다. 궁성 대각선을 따라 거는 장군도 곧은 길이다.
List<List<Square>> getAttackPaths(Position position, Side side) {
  final king = position.kingSquare(side);
  if (king == null) {
    return const [];
  }
  final paths = <List<Square>>[];
  for (final from in position.checkingSquares(side)) {
    final type = position.pieceAt(from)!.type;
    final df = king.file - from.file;
    final dr = king.rank - from.rank;
    final sideways = df.abs() > dr.abs();
    final straight = sideways ? Square(from.file + df.sign, from.rank) : Square(from.file, from.rank + dr.sign);
    switch (type) {
      case PieceType.horse:
        paths.add([from, straight, king]);
      case PieceType.elephant:
        paths.add([from, straight, Square(straight.file + df.sign, straight.rank + dr.sign), king]);
      case PieceType.king:
      case PieceType.chariot:
      case PieceType.cannon:
      case PieceType.advisor:
      case PieceType.soldier:
        paths.add([from, king]);
    }
  }
  return paths;
}

/// 장군 받은 궁의 빨간 테두리와 공격 길의 빨간 점선. 판 크기와 같은 칸에 그린다.
class CheckPathPainter extends CustomPainter {
  /// 점선 한 마디와 빈칸의 길이, 선 굵기(칸 크기의 배수).
  static const _dashCells = 0.16;
  static const _gapCells = 0.11;
  static const _lineWidthCells = 0.055;

  /// 궁 테두리의 반지름과 굵기(칸 크기의 배수).
  static const _ringRadiusCells = 0.56;
  static const _ringWidthCells = 0.07;

  final bool flipped;
  final Square king;
  final List<List<Square>> paths;

  const CheckPathPainter({required this.flipped, required this.king, required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = BoardGeometry(size, flipped: flipped);
    final cell = geometry.cell;
    const color = CheckColors.stamp;
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * _lineWidthCells
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final path in paths) {
      final polyline = Path()..moveTo(geometry.centerOf(path.first).dx, geometry.centerOf(path.first).dy);
      for (final square in path.skip(1)) {
        final point = geometry.centerOf(square);
        polyline.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(_dash(polyline, cell * _dashCells, cell * _gapCells), linePaint);
    }
    final center = geometry.centerOf(king);
    final radius = cell * _ringRadiusCells;
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..color = CheckColors.glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * _ringWidthCells * 2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.08),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * _ringWidthCells,
      );
  }

  static Path _dash(Path source, double dash, double gap) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashed.addPath(metric.extractPath(distance, math.min(distance + dash, metric.length)), Offset.zero);
        distance += dash + gap;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(CheckPathPainter oldDelegate) =>
      oldDelegate.flipped != flipped || oldDelegate.king != king || !_pathsEqual(oldDelegate.paths, paths);

  static bool _pathsEqual(List<List<Square>> a, List<List<Square>> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) {
        return false;
      }
      for (var j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) {
          return false;
        }
      }
    }
    return true;
  }
}

/// 장군 도장과 결과 도장의 색. 빨강은 한의 색이지만 도장(낙관)은 붉은 인주 색을 그대로 쓴다(`docs/ui.md`의 연출).
abstract final class CheckColors {
  /// 붉은 도장 바탕과 공격 길.
  static const stamp = Color(0xFFD23A2E);

  /// 도장 안쪽의 연한 테두리와 글자.
  static const paper = Color(0xFFFFF1E6);
  static const innerLine = Color(0xB3FFE1D6);

  /// 궁 테두리 둘레와 퍼지는 원의 번짐.
  static const glow = Color(0x99FF5A47);

  /// 패배 도장의 먹색 바탕과 그 둘레에 번지는 먹.
  static const ink = Color(0xFF26282C);
  static const inkGlow = Color(0x99000000);
}

/// 도장 글자(장군, 승, 패)의 붓글씨 글꼴(`docs/ui.md`의 디자인 방향). 앱에 넣은 송명(Song Myung)이다.
const stampFontFamily = 'SongMyung';

/// 붉은 "장군" 도장. 둥근 네모 안쪽에 연한 테두리를 두르고 살짝 기울인다.
class CheckStamp extends StatelessWidget {
  /// 도장 한 변.
  final double size;
  final String label;

  const CheckStamp({super.key, required this.size, required this.label});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.12,
      child: Container(
        width: size,
        height: size * 0.62,
        padding: EdgeInsets.all(size * 0.045),
        decoration: BoxDecoration(
          color: CheckColors.stamp,
          borderRadius: BorderRadius.circular(size * 0.12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: size * 0.08)],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.08),
            border: Border.all(color: CheckColors.innerLine, width: math.max(1, size * 0.02)),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              // 도장 크기가 판 크기로 정해지므로 글자 크기 설정을 따르지 않는다.
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: stampFontFamily,
                fontSize: size * 0.3,
                height: 1.1,
                color: CheckColors.paper,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 한 대국의 첫 장군 연출. 판 가운데에 큰 도장이 위에서 떨어지며 쿵 찍히고, 붉은 원이 한 번 퍼지고, 머문 뒤 먹이 번지듯
/// 흐려지며 사라진다. 그동안 판을 살짝 어둡게 깐다. [progress]는 이동 애니메이션이 시작한 때부터의 진행도(0~1)다.
class BigCheckStamp extends StatelessWidget {
  /// 연출 전체 시간. 처음 0.35초는 기물이 움직여 내려앉는 시간이다.
  static const duration = Duration(milliseconds: 2650);

  final Animation<double> progress;
  final String label;

  /// 판 크기. 도장은 판 짧은 변의 절반이다.
  final Size boardSize;

  const BigCheckStamp({super.key, required this.progress, required this.label, required this.boardSize});

  /// 판이 흔들리는 정도(-1~1). 도장이 찍힌 직후 짧게 흔들린다.
  static double getShake(double t) {
    final local = _interval(t, 650, 950);
    if (local <= 0 || local >= 1) {
      return 0;
    }
    return math.sin(local * math.pi * 6) * (1 - local);
  }

  /// 공격 길과 궁 위 작은 도장이 보이는 정도(0~1). 큰 도장이 흐려져 갈 때 나타나고, 연출 중이 아니면 늘 보인다.
  static double getMarksOpacity(double t) {
    if (t <= 0 || t >= 1) {
      return 1;
    }
    return _interval(t, 2150, 2650);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: progress, builder: _buildStamp);
  }

  Widget _buildStamp(BuildContext context, Widget? child) {
    final t = progress.value;
    if (t <= 0 || t >= 1) {
      return const SizedBox.shrink();
    }
    final drop = Curves.easeIn.transform(_interval(t, 400, 650));
    final ring = _interval(t, 650, 1250);
    final fade = Curves.easeIn.transform(_interval(t, 2150, 2650));
    final scrim = _interval(t, 400, 600) * (1 - fade);
    final size = boardSize.shortestSide * 0.5;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ColoredBox(color: GameColors.scrim.withValues(alpha: GameColors.scrim.a * scrim)),
        ),
        if (ring > 0 && ring < 1)
          CustomPaint(
            size: Size.square(size * (0.7 + ring * 1.3)),
            painter: _RingPainter(opacity: (1 - ring) * 0.9, width: size * 0.05),
          ),
        if (drop > 0)
          Opacity(
            opacity: drop * (1 - fade),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: fade * size * 0.06, sigmaY: fade * size * 0.06),
              child: Transform.scale(
                scale: (2.4 - 1.4 * drop) * (1 + fade * 0.08),
                child: CheckStamp(size: size, label: label),
              ),
            ),
          ),
      ],
    );
  }

  /// 전체 진행도 [t]가 [startMs]~[endMs] 구간에서 어디쯤인지(0~1).
  static double _interval(double t, int startMs, int endMs) {
    final ms = t * duration.inMilliseconds;
    return ((ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);
  }
}

/// 도장이 찍힐 때 한 번 퍼지는 붉은 원.
class _RingPainter extends CustomPainter {
  final double opacity;
  final double width;

  const _RingPainter({required this.opacity, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      Paint()
        ..color = CheckColors.stamp.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.opacity != opacity || oldDelegate.width != width;
}
