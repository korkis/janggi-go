import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/user_private.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';

/// 앱의 어느 화면에서든 제재 팝업을 띄운다(`docs/moderation.md`의 제재 단계와 안내). `JanggigoApp`이 모든 화면을 감싼다.
///
/// 앱을 켜거나 로그인했을 때, 또는 앱을 쓰는 중에 제재가 걸리면 한 번 알린다. 경고는 확인을 누르면 지운다. 대국이나 채팅을 하려다
/// 제재로 거절되면 [showSanctionDialogForError]가 다시 알린다.
class SanctionListener extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const SanctionListener({super.key, required this.navigatorKey, required this.child});

  @override
  State<SanctionListener> createState() => _SanctionListenerState();
}

class _SanctionListenerState extends State<SanctionListener> {
  // 이번 실행에서 팝업을 띄운 제재. 같은 제재로 두 번 띄우지 않는다.
  ActiveSanction? _shownSanction;

  @override
  void initState() {
    super.initState();
    managers.sanctionManager.addListener(_onSanctionChanged);
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
  }

  @override
  void dispose() {
    managers.sanctionManager.removeListener(_onSanctionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _onFirstFrame(Duration timeStamp) {
    _onSanctionChanged();
  }

  void _onSanctionChanged() {
    final sanction = managers.sanctionManager.sanction;
    if (sanction == null || _isSame(sanction, _shownSanction)) {
      return;
    }
    _shownSanction = sanction;
    _showDialog(sanction);
  }

  Future<void> _showDialog(ActiveSanction sanction) async {
    final context = widget.navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    await showSanctionDialog(context, sanction);
    if (sanction.type == SanctionType.warning) {
      await _clearWarning();
    }
  }

  /// 확인한 경고를 지운다. 실패하면 다음에 앱을 켤 때 다시 알린다.
  Future<void> _clearWarning() async {
    final uid = managers.authManager.uid;
    if (uid == null) {
      return;
    }
    try {
      await repositories.userPrivateRepository.clearWarning(uid);
    } catch (error, stackTrace) {
      developer.log('UserPrivateRepository.clearWarning 실패', error: error, stackTrace: stackTrace);
    }
  }

  static bool _isSame(ActiveSanction a, ActiveSanction? b) =>
      b != null && a.type == b.type && a.endsAt == b.endsAt && a.reason == b.reason;
}

/// 제재 팝업을 띄운다. 확인을 누르면 닫힌다.
Future<void> showSanctionDialog(BuildContext context, ActiveSanction sanction) async {
  await showDialog<void>(
    context: context,
    builder: (context) => SanctionDialog(sanction: sanction),
  );
}

/// 대국이나 채팅이 제재로 거절됐고 내게 걸린 제재를 알고 있으면 제재 팝업을 띄우고 true를 반환한다. 그 밖에는 false이고 화면이
/// 원래 오류 메시지를 보여준다.
Future<bool> showSanctionDialogForError(BuildContext context, Object error) async {
  final sanction = managers.sanctionManager.sanction;
  if (sanction == null || !isSanctionError(error)) {
    return false;
  }
  await showSanctionDialog(context, sanction);
  return true;
}

/// 제재(이용 정지, 채팅 제한)로 거절된 오류인지.
bool isSanctionError(Object error) =>
    error is AppException && (error.code == AppErrorCode.sanctioned || error.code == AppErrorCode.chatRestricted);

/// 제재 종류, 사유, 끝나는 때, 이의 제기 이메일을 보여주는 팝업.
class SanctionDialog extends StatelessWidget {
  final ActiveSanction sanction;

  const SanctionDialog({super.key, required this.sanction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final endsAt = sanction.endsAt?.toLocal();
    return AlertDialog(
      title: Text(_getTitle(l10n)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_getDescription(l10n)),
          const SizedBox(height: 12),
          // 사유: {reason}
          Text(l10n.sanctionReason(sanction.reason), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (endsAt != null && sanction.type != SanctionType.warning) ...[
            const SizedBox(height: 4),
            // 끝나는 때: {date} {time}
            Text(l10n.sanctionEndsAt(endsAt, endsAt)),
          ],
          const SizedBox(height: 12),
          Text(
            // 이의가 있으면 {email}로 메일을 보내 주세요
            l10n.sanctionAppeal(supportEmail),
            style: const TextStyle(color: LightColors.subText),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          // 확인
          child: Text(l10n.ok),
        ),
      ],
    );
  }

  String _getTitle(AppLocalizations l10n) => switch (sanction.type) {
    // 경고를 받았어요
    SanctionType.warning => l10n.sanctionTitleWarning,
    // 채팅이 제한되었어요
    SanctionType.chatRestriction => l10n.sanctionTitleChatRestriction,
    // 이용이 정지되었어요
    SanctionType.suspension => l10n.sanctionTitleSuspension,
    // 계정 이용이 영구 정지되었어요
    SanctionType.permanentBan => l10n.sanctionTitlePermanentBan,
    // 이용이 제한되었어요
    null => l10n.sanctionTitleUnknown,
  };

  String _getDescription(AppLocalizations l10n) => switch (sanction.type) {
    // 같은 일이 반복되면 채팅이나 이용이 제한될 수 있어요
    SanctionType.warning => l10n.sanctionDescriptionWarning,
    // 제한이 끝날 때까지 채팅을 할 수 없어요
    SanctionType.chatRestriction => l10n.sanctionDescriptionChatRestriction,
    // 정지가 끝날 때까지 대국과 채팅을 할 수 없어요
    SanctionType.suspension => l10n.sanctionDescriptionSuspension,
    // 대국과 채팅을 할 수 없어요
    SanctionType.permanentBan || null => l10n.sanctionDescriptionPermanentBan,
  };
}
