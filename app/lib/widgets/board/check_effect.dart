import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import 'board_geometry.dart';

/// 장군을 건 기물 둘레의 빨간 테두리(`docs/ui.md`의 연출). 어느 기물 때문에 장군인지만 보여준다. 판 크기와 같은 칸에 그린다.
class CheckerRingPainter extends CustomPainter {
  /// 테두리의 반지름과 굵기(칸 크기의 배수).
  static const _ringRadiusCells = 0.5;
  static const _ringWidthCells = 0.06;

  final bool flipped;

  /// 장군을 건 기물의 칸.
  final List<Square> checkers;

  const CheckerRingPainter({required this.flipped, required this.checkers});

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = BoardGeometry(size, flipped: flipped);
    final cell = geometry.cell;
    final paint = Paint()
      ..color = CheckColors.stamp
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * _ringWidthCells;
    for (final square in checkers) {
      canvas.drawCircle(geometry.centerOf(square), cell * _ringRadiusCells, paint);
    }
  }

  @override
  bool shouldRepaint(CheckerRingPainter oldDelegate) =>
      oldDelegate.flipped != flipped || !_squaresEqual(oldDelegate.checkers, checkers);

  static bool _squaresEqual(List<Square> a, List<Square> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// 장군 도장과 결과 도장의 색. 빨강은 한의 색이지만 도장(낙관)은 붉은 인주 색을 그대로 쓴다(`docs/ui.md`의 연출).
abstract final class CheckColors {
  /// 붉은 도장 바탕과 장군을 건 기물의 테두리.
  static const stamp = Color(0xFFD23A2E);

  /// 도장 안쪽의 연한 테두리와 글자.
  static const paper = Color(0xFFFFF1E6);
  static const innerLine = Color(0xB3FFE1D6);

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

/// 장군을 걸 때마다 띄우는 연출. 판 가운데에 큰 도장이 위에서 떨어지며 쿵 찍히고, 붉은 원이 한 번 퍼지고, 머문 뒤 먹이 번지듯
/// 흐려지며 사라진다. 판은 어둡게 하지 않는다. [progress]는 이동 애니메이션이 시작한 때부터의 진행도(0~1)다.
class BigCheckStamp extends StatelessWidget {
  /// 연출 전체 시간. 처음 0.35초는 기물이 움직여 내려앉는 시간이다.
  static const duration = Duration(milliseconds: 2650);

  final Animation<double> progress;
  final String label;

  /// 판 크기. 도장은 판 짧은 변의 절반이다.
  final Size boardSize;

  const BigCheckStamp({super.key, required this.progress, required this.label, required this.boardSize});

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
    final size = boardSize.shortestSide * 0.5;
    return Stack(
      alignment: Alignment.center,
      children: [
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
