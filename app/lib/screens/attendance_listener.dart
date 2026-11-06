import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';

/// 출석 엽전을 받으면 어느 화면에서든 아래에 잠깐 알린다(`docs/screens.md`의 홈). 지급은 [CoinManager]가 한다.
class AttendanceListener extends StatefulWidget {
  final Widget child;

  const AttendanceListener({super.key, required this.child});

  @override
  State<AttendanceListener> createState() => _AttendanceListenerState();
}

class _AttendanceListenerState extends State<AttendanceListener> {
  @override
  void initState() {
    super.initState();
    managers.coinManager.addListener(_onCoinChanged);
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
  }

  @override
  void dispose() {
    managers.coinManager.removeListener(_onCoinChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// 첫 화면이 뜨기 전에 받은 출석을 알린다.
  void _onFirstFrame(Duration timeStamp) {
    _onCoinChanged();
  }

  void _onCoinChanged() {
    final amount = managers.coinManager.takeAttendanceGrant();
    if (amount == null || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    // 출석 +30엽전
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.coinAttendanceGranted(amount))));
  }
}
