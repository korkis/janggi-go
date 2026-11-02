import 'package:flutter/material.dart';

/// Google 로그인 버튼의 G 로고. 원래 색으로 그린다.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: size, child: const CustomPaint(painter: _GoogleLogoPainter()));
  }
}

/// Apple 로그인 버튼의 사과 로고. [color] 한 가지로 그린다.
class AppleLogo extends StatelessWidget {
  final double size;
  final Color color;

  const AppleLogo({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _AppleLogoPainter(color)),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  // 로고를 그린 좌표계의 한 변 길이.
  static const _viewBox = 48.0;

  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _viewBox, size.height / _viewBox);
    final paint = Paint()..isAntiAlias = true;
    final red = Path()
      ..moveTo(24, 9.5)
      ..cubicTo(27.5, 9.5, 30.6, 10.7, 33.1, 13.1)
      ..lineTo(39.9, 6.3)
      ..cubicTo(35.8, 2.4, 30.3, 0, 24, 0)
      ..cubicTo(14.6, 0, 6.6, 5.4, 2.7, 13.2)
      ..lineTo(10.6, 19.4)
      ..cubicTo(12.5, 13.6, 17.8, 9.5, 24, 9.5)
      ..close();
    final blue = Path()
      ..moveTo(46.5, 24.5)
      ..cubicTo(46.5, 22.9, 46.4, 21.4, 46.1, 20)
      ..lineTo(24, 20)
      ..lineTo(24, 29)
      ..lineTo(36.7, 29)
      ..cubicTo(36.1, 32, 34.4, 34.5, 31.9, 36.2)
      ..lineTo(39.6, 42.2)
      ..cubicTo(44.1, 38, 46.5, 31.9, 46.5, 24.5)
      ..close();
    final yellow = Path()
      ..moveTo(10.6, 28.6)
      ..cubicTo(10.1, 27.2, 9.8, 25.6, 9.8, 24)
      ..cubicTo(9.8, 22.4, 10.1, 20.8, 10.6, 19.4)
      ..lineTo(2.7, 13.2)
      ..cubicTo(1, 16.6, 0, 20.2, 0, 24)
      ..cubicTo(0, 27.8, 1, 31.4, 2.7, 34.8)
      ..lineTo(10.6, 28.6)
      ..close();
    final green = Path()
      ..moveTo(24, 48)
      ..cubicTo(30.5, 48, 35.9, 45.9, 39.9, 42.2)
      ..lineTo(32.2, 36.2)
      ..cubicTo(30, 37.7, 27.2, 38.5, 24, 38.5)
      ..cubicTo(17.8, 38.5, 12.5, 34.4, 10.6, 28.7)
      ..lineTo(2.7, 34.9)
      ..cubicTo(6.6, 42.6, 14.6, 48, 24, 48)
      ..close();
    canvas.drawPath(red, paint..color = const Color(0xFFEA4335));
    canvas.drawPath(blue, paint..color = const Color(0xFF4285F4));
    canvas.drawPath(yellow, paint..color = const Color(0xFFFBBC05));
    canvas.drawPath(green, paint..color = const Color(0xFF34A853));
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}

class _AppleLogoPainter extends CustomPainter {
  // 로고를 그린 좌표계. 가로 20, 세로 24이고 가운데에 놓는다.
  static const _viewBoxWidth = 20.0;
  static const _viewBoxHeight = 24.0;

  final Color color;

  const _AppleLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _viewBoxHeight;
    canvas.translate((size.width - _viewBoxWidth * scale) / 2, 0);
    canvas.scale(scale);
    final path = Path()
      ..moveTo(16.4, 12.7)
      ..cubicTo(16.4, 10.1, 18.5, 8.9, 18.6, 8.8)
      ..cubicTo(17.4, 7, 15.5, 6.8, 14.9, 6.8)
      ..cubicTo(13.3, 6.6, 11.8, 7.7, 11, 7.7)
      ..cubicTo(10.2, 7.7, 9, 6.8, 7.6, 6.8)
      ..cubicTo(5.9, 6.8, 4.3, 7.8, 3.4, 9.4)
      ..cubicTo(1.6, 12.5, 2.9, 17.1, 4.7, 19.6)
      ..cubicTo(5.6, 20.8, 6.6, 22.2, 7.9, 22.2)
      ..cubicTo(9.2, 22.1, 9.7, 21.4, 11.2, 21.4)
      ..cubicTo(12.8, 21.4, 13.2, 22.2, 14.6, 22.2)
      ..cubicTo(16, 22.2, 16.9, 20.9, 17.7, 19.7)
      ..cubicTo(18.7, 18.3, 19.1, 16.9, 19.1, 16.8)
      ..cubicTo(19.1, 16.8, 16.4, 15.8, 16.4, 12.7)
      ..close()
      ..moveTo(13.9, 5.1)
      ..cubicTo(14.6, 4.2, 15.1, 3, 15, 1.8)
      ..cubicTo(14, 1.8, 12.7, 2.5, 12, 3.4)
      ..cubicTo(11.3, 4.2, 10.8, 5.4, 10.9, 6.6)
      ..cubicTo(12, 6.7, 13.2, 6, 13.9, 5.1)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AppleLogoPainter oldDelegate) => oldDelegate.color != color;
}
