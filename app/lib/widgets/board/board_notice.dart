import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 판 위쪽에 잠깐 띄울 알림 하나. 같은 글자라도 새 값이면 처음부터 다시 띄운다.
class BoardNoticeMessage {
  final String text;

  const BoardNoticeMessage(this.text);
}

/// 판 위쪽에 잠깐 띄우는 작은 알림(`docs/screens.md`의 대국 화면). 시계가 흐르므로 닫을 필요 없이 저절로 사라지고 누름을 막지 않는다.
class BoardNotice extends StatefulWidget {
  /// 알림을 띄우는 시간.
  static const duration = Duration(milliseconds: 2500);

  final BoardNoticeMessage? message;

  const BoardNotice({super.key, required this.message});

  @override
  State<BoardNotice> createState() => _BoardNoticeState();
}

class _BoardNoticeState extends State<BoardNotice> with SingleTickerProviderStateMixin {
  // 잠깐 나타났다 사라질 뿐이고 읽을 시간은 애니메이션 줄이기 설정과 상관없이 같아야 하므로 시간을 줄이지 않는다.
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: BoardNotice.duration,
      animationBehavior: AnimationBehavior.preserve,
    );
    _opacity = _controller.drive(
      TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 82),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
      ]),
    );
    if (widget.message != null) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BoardNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.message, widget.message) && widget.message != null) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    if (message == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Semantics(
            liveRegion: true,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xEB101216), borderRadius: BorderRadius.circular(12)),
              child: Text(
                message.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTextSizes.body,
                  fontWeight: FontWeight.w700,
                  color: GameColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
