import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../../l10n/app_localizations.dart';
import '../../managers/board_manager.dart';

/// 둘 수 없는 수를 눌렀을 때 판 가운데에 1초쯤 띄우는 이유(`docs/ui.md`의 판 위 표시).
class RejectionNotice extends StatefulWidget {
  /// 안내를 띄우는 시간.
  static const duration = Duration(milliseconds: 1000);

  /// 띄울 일. 새 값이 들어올 때마다 처음부터 다시 띄우고, null이면 바로 지운다.
  final RejectedTap? rejectedTap;

  const RejectionNotice({super.key, required this.rejectedTap});

  @override
  State<RejectionNotice> createState() => _RejectionNoticeState();
}

class _RejectionNoticeState extends State<RejectionNotice> with SingleTickerProviderStateMixin {
  // 잠깐 나타났다 사라질 뿐이고, 안내를 읽을 시간은 애니메이션 줄이기 설정과 상관없이 같아야 하므로 시간을 줄이지 않는다.
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: RejectionNotice.duration,
      animationBehavior: AnimationBehavior.preserve,
    );
    _opacity = _controller.drive(
      TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
      ]),
    );
    if (widget.rejectedTap != null) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RejectionNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.rejectedTap, widget.rejectedTap)) {
      return;
    }
    if (widget.rejectedTap == null) {
      _controller.value = 0;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejectedTap = widget.rejectedTap;
    if (rejectedTap == null) {
      return const SizedBox.shrink();
    }
    return Center(
      child: FadeTransition(
        opacity: _opacity,
        child: Semantics(
          liveRegion: true,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xE6201A14), borderRadius: BorderRadius.circular(8)),
            child: Text(
              _getMessage(AppLocalizations.of(context), rejectedTap.reason),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  String _getMessage(AppLocalizations l10n, MoveRejection reason) {
    switch (reason) {
      case MoveRejection.mustStopCheck:
        // 장군을 막아야 합니다
        return l10n.moveRejectedMustStopCheck;
      case MoveRejection.exposesGeneral:
        // 궁이 장군을 받습니다
        return l10n.moveRejectedExposesGeneral;
      case MoveRejection.repetition:
        // 반복수입니다
        return l10n.moveRejectedRepetition;
    }
  }
}
