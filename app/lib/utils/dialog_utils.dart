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
