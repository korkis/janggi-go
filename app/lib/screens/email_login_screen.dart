import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../widgets/adaptive_layout.dart';

/// 이메일 로그인과 이메일 가입 화면(`docs/screens.md`의 이메일 로그인). 로그인하면 true를 돌려주며 닫는다.
class EmailLoginScreen extends StatefulWidget {
  /// 가입 화면이면 true. 로그인 화면과 같은 구성에 비밀번호 확인 칸을 더한다.
  final bool signUp;

  const EmailLoginScreen({super.key, required this.signUp});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  // Firebase Auth가 받는 가장 짧은 비밀번호 길이.
  static const _minPasswordLength = 6;
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _passwordVisible = false;
  bool _passwordConfirmVisible = false;
  bool _submitting = false;
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signUp = widget.signUp;
    return AppPage(
      layout: PageLayout.form,
      child: Scaffold(
        appBar: AppBar(
          // 넓은 화면의 흰 카드 안에서는 흰 바탕이 된다.
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          leading: BackButton(onPressed: _onBack),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Text(
                      // 이메일로 가입하기 / 이메일로 로그인
                      signUp ? l10n.emailSignUpTitle : l10n.emailLoginTitle,
                      style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      // 로그인에 쓸 이메일과 비밀번호를 정해 주세요. / 가입할 때 쓴 이메일과 비밀번호를 넣어 주세요.
                      signUp ? l10n.emailSignUpDescription : l10n.emailLoginDescription,
                      style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                    ),
                    const SizedBox(height: 28),
                    _FieldLabel(
                      // 이메일
                      l10n.email,
                    ),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: AppTextSizes.body),
                      decoration: _inputDecoration(errorText: _emailError),
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel(
                      // 비밀번호
                      l10n.password,
                    ),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
                      textInputAction: signUp ? TextInputAction.next : TextInputAction.done,
                      onSubmitted: signUp ? null : _onSubmitted,
                      style: const TextStyle(fontSize: AppTextSizes.body),
                      decoration: _inputDecoration(
                        errorText: _passwordError,
                        suffixIcon: IconButton(
                          onPressed: _onTogglePasswordVisible,
                          // 비밀번호 숨기기 / 비밀번호 보기
                          tooltip: _passwordVisible ? l10n.hidePassword : l10n.showPassword,
                          icon: Icon(_passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                      ),
                    ),
                    if (signUp) ...[
                      const SizedBox(height: 16),
                      _FieldLabel(
                        // 비밀번호 확인
                        l10n.passwordConfirm,
                      ),
                      TextField(
                        controller: _passwordConfirmController,
                        obscureText: !_passwordConfirmVisible,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onSubmitted: _onSubmitted,
                        style: const TextStyle(fontSize: AppTextSizes.body),
                        decoration: _inputDecoration(
                          errorText: _passwordConfirmError,
                          suffixIcon: IconButton(
                            onPressed: _onTogglePasswordConfirmVisible,
                            // 비밀번호 확인 숨기기 / 비밀번호 확인 보기
                            tooltip: _passwordConfirmVisible ? l10n.hidePasswordConfirm : l10n.showPasswordConfirm,
                            icon: Icon(
                              _passwordConfirmVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _submitting ? null : _onForgotPassword,
                          // 비밀번호를 잊으셨나요?
                          child: Text(l10n.forgotPassword),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: _submitting ? null : _onSubmit,
                      child: _submitting
                          ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          // 가입하기 / 로그인
                          : Text(signUp ? l10n.signUp : l10n.login),
                    ),
                    if (!signUp) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            // 처음이신가요?
                            l10n.emailSignUpPrompt,
                            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                          ),
                          TextButton(
                            onPressed: _submitting ? null : _onSignUp,
                            // 이메일로 가입하기
                            child: Text(l10n.emailSignUpTitle),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String? errorText, Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: LightColors.surface,
      errorText: errorText,
      errorMaxLines: 2,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LightColors.outline, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LightColors.accent, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  void _onBack() {
    Navigator.of(context).pop(false);
  }

  void _onTogglePasswordVisible() {
    setState(() => _passwordVisible = !_passwordVisible);
  }

  void _onTogglePasswordConfirmVisible() {
    setState(() => _passwordConfirmVisible = !_passwordConfirmVisible);
  }

  void _onSubmitted(String _) {
    if (!_submitting) {
      _onSubmit();
    }
  }

  Future<void> _onSignUp() async {
    final signedIn = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (context) => const EmailLoginScreen(signUp: true)));
    if (signedIn == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// 입력을 검사해 칸 아래에 오류를 보여준다. 고칠 것이 없으면 true.
  bool _validate(AppLocalizations l10n) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      // 이메일 주소를 다시 확인해 주세요
      _emailError = _emailPattern.hasMatch(email) ? null : l10n.errorInvalidEmail;
      _passwordError = null;
      _passwordConfirmError = null;
      if (password.isEmpty) {
        // 비밀번호를 넣어 주세요
        _passwordError = l10n.errorPasswordEmpty;
      } else if (widget.signUp && password.length < _minPasswordLength) {
        // 비밀번호는 6자 이상으로 정해 주세요
        _passwordError = l10n.errorWeakPassword;
      }
      if (widget.signUp && _passwordConfirmController.text != password) {
        // 비밀번호가 서로 달라요
        _passwordConfirmError = l10n.errorPasswordMismatch;
      }
    });
    return _emailError == null && _passwordError == null && _passwordConfirmError == null;
  }

  Future<void> _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (!_validate(l10n)) {
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    try {
      setState(() => _submitting = true);
      if (widget.signUp) {
        await managers.authManager.createEmailAccount(email: email, password: password);
      } else {
        await managers.authManager.signInWithEmail(email: email, password: password);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      developer.log('AuthManager 이메일 로그인 실패: signUp=${widget.signUp}', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 로그인하지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorSignIn;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _onForgotPassword() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      // 비밀번호를 다시 정할 이메일을 넣어 주세요
      setState(() => _emailError = l10n.errorPasswordResetEmail);
      return;
    }
    setState(() => _emailError = null);
    try {
      setState(() => _submitting = true);
      await repositories.authRepository.sendPasswordResetEmail(email);
      if (mounted) {
        // 비밀번호를 다시 정하는 메일을 보냈어요. 메일함을 확인해 주세요.
        await DialogUtils.showMessage(context, message: l10n.passwordResetSent);
      }
    } catch (error, stackTrace) {
      developer.log('AuthRepository.sendPasswordResetEmail 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 메일을 보내지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorPasswordReset;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
      ),
    );
  }
}
