import 'dart:math' as math;

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

/// 장군을 걸 때마다 장군 받은 궁 바로 위에 작은 "장군" 도장을 찍는다(`docs/ui.md`의 연출). 기물이 내려앉은 뒤 조금 크게
/// 나타나 제자리로 톡 찍히고, 잠시 머문 뒤 흐려지며 사라진다. 판을 가리지 않도록 칸 크기만 하다.
/// [progress]는 이동 애니메이션이 시작한 때부터의 진행도(0~1)다.
class CheckStampPop extends StatelessWidget {
  /// 연출 전체 시간. 처음 0.35초는 기물이 움직여 내려앉는 시간이다.
  static const duration = Duration(milliseconds: 1850);

  /// 도장 한 변(칸 크기의 배수)과 궁 가운데에서 도장 가운데까지의 높이.
  static const _sizeCells = 1.1;
  static const _liftCells = 0.95;

  final Animation<double> progress;
  final String label;
  final Position position;

  /// 장군 받은 진영.
  final Side side;
  final bool flipped;
  final Size boardSize;

  const CheckStampPop({
    super.key,
    required this.progress,
    required this.label,
    required this.position,
    required this.side,
    required this.flipped,
    required this.boardSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: progress, builder: _buildStamp);
  }

  Widget _buildStamp(BuildContext context, Widget? child) {
    final t = progress.value;
    final king = _getKingSquare();
    if (t <= 0 || t >= 1 || king == null) {
      return const SizedBox.shrink();
    }
    final pop = Curves.easeOut.transform(_interval(t, 350, 550));
    final fade = Curves.easeIn.transform(_interval(t, 1550, 1850));
    if (pop <= 0) {
      return const SizedBox.shrink();
    }
    final geometry = BoardGeometry(boardSize, flipped: flipped);
    final size = geometry.cell * _sizeCells;
    final center = geometry.centerOf(king).translate(0, -geometry.cell * _liftCells);
    return Stack(
      children: [
        Positioned(
          left: center.dx - size / 2,
          top: center.dy - size * 0.31,
          child: Opacity(
            opacity: pop * (1 - fade),
            child: Transform.scale(
              scale: 1.3 - 0.3 * pop,
              child: CheckStamp(size: size, label: label),
            ),
          ),
        ),
      ],
    );
  }

  Square? _getKingSquare() {
    for (final MapEntry(key: square, value: piece) in position.pieces.entries) {
      if (piece == Piece(side, PieceType.king)) {
        return square;
      }
    }
    return null;
  }

  /// 전체 진행도 [t]가 [startMs]~[endMs] 구간에서 어디쯤인지(0~1).
  static double _interval(double t, int startMs, int endMs) {
    final ms = t * duration.inMilliseconds;
    return ((ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);
  }
}
