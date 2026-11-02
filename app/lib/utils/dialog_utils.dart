import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 커스텀이 적은 다이얼로그. 기본으로 제목을 두지 않는다.
abstract final class DialogUtils {
  /// [message]를 보여주고 [confirmLabel]을 누르면 true, 취소하거나 닫으면 false를 반환한다.
  static Future<bool> showConfirm(BuildContext context, {required String message, required String confirmLabel}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(message: message, confirmLabel: confirmLabel),
    );
    return confirmed ?? false;
  }

  /// [message]를 보여주고 확인을 누르면 닫는다.
  static Future<void> showMessage(BuildContext context, {required String message}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _MessageDialog(message: message),
    );
  }
}

class _MessageDialog extends StatelessWidget {
  final String message;

  const _MessageDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      content: Text(message),
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

class _ConfirmDialog extends StatelessWidget {
  final String message;
  final String confirmLabel;

  const _ConfirmDialog({required this.message, required this.confirmLabel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          // 취소
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirmLabel)),
      ],
    );
  }
}
