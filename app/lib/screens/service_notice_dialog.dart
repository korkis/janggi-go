import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/app_config.dart';

/// 공지(`configs/app.serviceNotice`)를 어느 화면에서든 한 번 띄운다(`docs/screens.md`의 공지). 대국 중이면 시계가 흐르므로 끝난 뒤
/// 띄운다. `JanggigoApp`이 모든 화면을 감싼다.
class ServiceNoticeListener extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const ServiceNoticeListener({super.key, required this.navigatorKey, required this.child});

  @override
  State<ServiceNoticeListener> createState() => _ServiceNoticeListenerState();
}

class _ServiceNoticeListenerState extends State<ServiceNoticeListener> {
  // 이번 실행에서 띄운 공지. 같은 공지를 두 번 띄우지 않는다.
  ServiceNotice? _shownNotice;

  @override
  void initState() {
    super.initState();
    managers.appConfigManager.addListener(_onChanged);
    managers.playerStateManager.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
  }

  @override
  void dispose() {
    managers.appConfigManager.removeListener(_onChanged);
    managers.playerStateManager.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _onFirstFrame(Duration timeStamp) {
    _onChanged();
  }

  void _onChanged() {
    final notice = managers.appConfigManager.serviceNotice;
    if (notice == null) {
      _shownNotice = null;
      return;
    }
    if (_isSame(notice, _shownNotice) || managers.playerStateManager.gameId != null) {
      return;
    }
    final context = widget.navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    _shownNotice = notice;
    showDialog<void>(
      context: context,
      builder: (context) => _ServiceNoticeDialog(notice: notice),
    );
  }

  static bool _isSame(ServiceNotice a, ServiceNotice? b) =>
      b != null && a.messageKo == b.messageKo && a.messageEn == b.messageEn;
}

class _ServiceNoticeDialog extends StatelessWidget {
  final ServiceNotice notice;

  const _ServiceNoticeDialog({required this.notice});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final korean = Localizations.localeOf(context).languageCode == 'ko';
    return AlertDialog(
      content: Text(korean ? notice.messageKo : notice.messageEn),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          // 확인
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
