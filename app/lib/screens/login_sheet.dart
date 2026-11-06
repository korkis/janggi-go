import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/brand_logos.dart';
import 'email_login_screen.dart';
import 'login_flow.dart';

enum _SignInMethod { google, apple }

/// 하던 화면 위에 아래에서 올라오는 로그인 창(`docs/screens.md`의 로그인 창).
///
/// 600 이상은 폭 480으로 모으고, 1024 이상은 아래에서 올리지 않고 가운데 카드로 띄운다(`docs/ui.md`의 넓은 화면).
class LoginSheet extends StatefulWidget {
  final LoginPurpose purpose;

  const LoginSheet({super.key, required this.purpose});

  /// 로그인 창을 띄운다. 로그인했으면 true, 닫았으면 false.
  static Future<bool> show(BuildContext context, LoginPurpose purpose) async {
    if (getLayoutSize(context) == LayoutSize.expanded) {
      final signedIn = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: LightColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: LayoutWidths.formCard),
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: LoginSheet(purpose: purpose),
            ),
          ),
        ),
      );
      return signedIn ?? false;
    }
    final signedIn = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: LayoutWidths.mediumContent),
      builder: (context) => LoginSheet(purpose: purpose),
    );
    return signedIn ?? false;
  }

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  // 로그인하는 중인 방법. 그동안 버튼을 막는다.
  _SignInMethod? _signingInMethod;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _signingInMethod != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitle(l10n),
                        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        // 온라인 대국은 로그인 후 둘 수 있어요.\n급수와 전적이 저장돼요.
                        l10n.loginSheetDescription,
                        style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _onClose,
                  // 닫기
                  tooltip: l10n.close,
                  color: LightColors.subText,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SignInButton(
              onPressed: busy ? null : _onGoogle,
              loading: _signingInMethod == _SignInMethod.google,
              background: LightColors.surface,
              foreground: LightColors.text,
              borderColor: LightColors.outline,
              icon: const GoogleLogo(size: 22),
              // Google로 계속하기
              label: l10n.loginWithGoogle,
            ),
            const SizedBox(height: 10),
            _SignInButton(
              onPressed: busy ? null : _onApple,
              loading: _signingInMethod == _SignInMethod.apple,
              background: Colors.black,
              foreground: Colors.white,
              icon: const AppleLogo(size: 22, color: Colors.white),
              // Apple로 계속하기
              label: l10n.loginWithApple,
            ),
            const SizedBox(height: 10),
            _SignInButton(
              onPressed: busy ? null : _onEmail,
              loading: false,
              background: LightColors.mutedSurface,
              foreground: LightColors.text,
              icon: const Icon(Icons.mail_outline, size: 22),
              // 이메일로 계속하기
              label: l10n.loginWithEmail,
            ),
            const SizedBox(height: 20),
            _TermsNotice(l10n: l10n),
          ],
        ),
      ),
    );
  }

  String _getTitle(AppLocalizations l10n) => switch (widget.purpose) {
    // 로그인하고\n온라인 대국을 둬 보세요
    LoginPurpose.home => l10n.loginSheetTitleHome,
    // 로그인하면 바로\n상대를 찾아 드릴게요
    LoginPurpose.quickMatch => l10n.loginSheetTitleQuickMatch,
    // 로그인하면 바로\n방을 만들 수 있어요
    LoginPurpose.createRoom => l10n.loginSheetTitleCreateRoom,
    // 로그인하고\n대국실에 들어가 보세요
    LoginPurpose.lobby => l10n.loginSheetTitleLobby,
    // 로그인하면 바로\n초대받은 방에 들어가요
    LoginPurpose.joinRoom => l10n.loginSheetTitleJoinRoom,
    // 로그인하면 관전하면서\n채팅할 수 있어요
    LoginPurpose.spectateChat => l10n.loginSheetTitleSpectateChat,
    // 로그인하면\n내 기보를 볼 수 있어요
    LoginPurpose.records => l10n.loginSheetTitleRecords,
    // 로그인하면\n급수와 전적을 볼 수 있어요
    LoginPurpose.profile => l10n.loginSheetTitleProfile,
    // 로그인하면 상점을 쓸 수 있어요
    LoginPurpose.store => l10n.loginSheetTitleStore,
  };

  void _onClose() {
    Navigator.of(context).pop(false);
  }

  Future<void> _onGoogle() async {
    await _signIn(_SignInMethod.google);
  }

  Future<void> _onApple() async {
    await _signIn(_SignInMethod.apple);
  }

  Future<void> _signIn(_SignInMethod method) async {
    try {
      setState(() => _signingInMethod = method);
      final authManager = managers.authManager;
      switch (method) {
        case _SignInMethod.google:
          await authManager.signInWithGoogle();
        case _SignInMethod.apple:
          await authManager.signInWithApple();
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      if (error is AppException && error.code == AppErrorCode.signInCanceled) {
        return;
      }
      developer.log('AuthManager 로그인 실패: ${method.name}', error: error, stackTrace: stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 로그인하지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorSignIn;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() => _signingInMethod = null);
      }
    }
  }

  Future<void> _onEmail() async {
    final signedIn = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (context) => const EmailLoginScreen(signUp: false)));
    if (signedIn == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

/// 로그인 방법 버튼. 세 버튼은 같은 크기다.
class _SignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final Widget icon;
  final String label;

  const _SignInButton({
    required this.onPressed,
    required this.loading,
    required this.background,
    required this.foreground,
    this.borderColor,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = this.borderColor;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground.withValues(alpha: 0.6),
        side: borderColor == null ? null : BorderSide(color: borderColor, width: 1.5),
        textStyle: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: foreground))
          else
            icon,
          const SizedBox(width: 10),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

/// 계속하면 약관에 동의하는 것으로 본다는 안내. 두 문서 이름은 굵게 쓴다.
class _TermsNotice extends StatelessWidget {
  final AppLocalizations l10n;

  const _TermsNotice({required this.l10n});

  @override
  Widget build(BuildContext context) {
    // 이용약관
    final terms = l10n.termsOfService;
    // 개인정보처리방침
    final privacy = l10n.privacyPolicy;
    // 계속하면 만 14세 이상이며 {terms}과 {privacy}에\n동의하는 것으로 봅니다.
    final notice = l10n.loginTermsNotice(terms, privacy);
    return Text.rich(
      TextSpan(children: _buildSpans(notice, [terms, privacy])),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15, color: LightColors.subText, height: 1.6),
    );
  }

  /// [text]에서 [boldParts]를 굵게 한 조각들.
  List<TextSpan> _buildSpans(String text, List<String> boldParts) {
    const boldStyle = TextStyle(color: LightColors.text, fontWeight: FontWeight.w700);
    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      var nextIndex = -1;
      var nextPart = '';
      for (final part in boldParts) {
        final index = text.indexOf(part, start);
        if (index >= 0 && (nextIndex < 0 || index < nextIndex)) {
          nextIndex = index;
          nextPart = part;
        }
      }
      if (nextIndex < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (nextIndex > start) {
        spans.add(TextSpan(text: text.substring(start, nextIndex)));
      }
      spans.add(TextSpan(text: nextPart, style: boldStyle));
      start = nextIndex + nextPart.length;
    }
    return spans;
  }
}
