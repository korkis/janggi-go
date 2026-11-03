import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';

/// 대국 신청의 남은 응답 시간 막대(`docs/screens.md`의 대국 신청). [createdAt]부터 [expiresAt]까지 줄어든다.
///
/// 서버 시각은 RTDB `.info/serverTimeOffset`으로 어림한다. 마감은 서버가 정하므로 막대가 다 줄어도 화면은 서버의 신청 상태를
/// 보고 닫는다.
class ChallengeTimeBar extends StatefulWidget {
  final DateTime createdAt;
  final DateTime expiresAt;

  const ChallengeTimeBar({super.key, required this.createdAt, required this.expiresAt});

  @override
  State<ChallengeTimeBar> createState() => _ChallengeTimeBarState();
}

class _ChallengeTimeBarState extends State<ChallengeTimeBar> {
  static const _tickInterval = Duration(milliseconds: 100);

  StreamSubscription<Duration>? _offsetSubscription;
  Timer? _ticker;
  var _serverTimeOffset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _offsetSubscription = repositories.serverTimeRepository.watchServerTimeOffset().listen(
      _onOffsetChanged,
      onError: _onOffsetError,
    );
    _ticker = Timer.periodic(_tickInterval, _onTick);
  }

  @override
  void dispose() {
    _offsetSubscription?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.expiresAt.difference(widget.createdAt).inMilliseconds;
    final left = widget.expiresAt.difference(DateTime.now().toUtc().add(_serverTimeOffset)).inMilliseconds;
    final value = total <= 0 ? 0.0 : (left / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        color: LightColors.accent,
        backgroundColor: LightColors.mutedSurface,
      ),
    );
  }

  void _onTick(Timer timer) {
    setState(() {});
  }

  void _onOffsetChanged(Duration offset) {
    _serverTimeOffset = offset;
  }

  void _onOffsetError(Object error, StackTrace stackTrace) {
    developer.log('ChallengeTimeBar serverTimeOffset 듣기 실패', error: error, stackTrace: stackTrace);
  }
}
