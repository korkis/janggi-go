import 'package:flutter/material.dart';

/// 다음 급수까지의 진행 막대(`docs/game/rank.md`의 화면 표시). 현재 급수 구간 안에서 레이팅이 어디쯤인지 0~1로 보여준다.
///
/// [previous]를 주면 이번 대국으로 늘거나 줄어든 부분을 [changeColor]로 구분해 보여준다. 늘었으면 [previous]부터 [progress]
/// 까지, 줄었으면 [progress]부터 [previous]까지다.
class RankProgressBar extends StatelessWidget {
  final double progress;
  final double? previous;
  final Color color;
  final Color trackColor;
  final Color changeColor;

  const RankProgressBar({
    super.key,
    required this.progress,
    this.previous,
    required this.color,
    required this.trackColor,
    required this.changeColor,
  });

  static const _height = 10.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_height / 2),
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(builder: _buildBar),
      ),
    );
  }

  Widget _buildBar(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final current = progress.clamp(0.0, 1.0);
    final before = (previous ?? current).clamp(0.0, 1.0);
    final solidEnd = current < before ? current : before;
    final changeEnd = current < before ? before : current;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: trackColor)),
        Positioned(
          left: solidEnd * width,
          top: 0,
          bottom: 0,
          width: (changeEnd - solidEnd) * width,
          child: ColoredBox(color: changeColor),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: solidEnd * width,
          child: ColoredBox(color: color),
        ),
      ],
    );
  }
}
