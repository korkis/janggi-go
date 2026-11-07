import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/app_language.dart';
import '../models/sign_in_method.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../widgets/adaptive_layout.dart';

/// 설정(`docs/screens.md`의 설정). 내 정보에서 열고, 1024 이상은 왼쪽 메뉴로도 연다. 로그인하지 않아도 본다.
///
/// 대국(소리, 진동, 대국 신청 받기), 계정(로그인 방식, 로그아웃, 회원 탈퇴), 언어, 정보(이용약관, 개인정보처리방침, 버전, 오픈소스 라이선스)
/// 묶음을 둔다. 대국 신청 받기와 계정은 로그인한 사용자에게만 보여준다. 진동은 웹에서 울릴 수 없어 웹에서는 두지 않는다.
/// 약관과 처리방침 연결은 구현 순서 9번에서 넣는다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// 1024 이상의 왼쪽 메뉴에서 처음 화면(홈) 위에 설정을 연다.
  static Future<void> open(BuildContext context) => openMenuScreen(Navigator.of(context), _build);

  static Widget _build(BuildContext context) => const SettingsScreen();

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // `users_private.challengesEnabled`. 대국실 항목이 없을 때 쓴다. 읽기 전과 읽지 못했을 때는 null이다.
  bool? _challengesEnabled;
  var _changingChallengesEnabled = false;
  var _signingOut = false;
  var _deletingAccount = false;

  // 앱 버전. 읽기 전과 읽지 못했을 때는 null이다.
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadChallengesEnabled();
    _loadVersion();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      menu: AppMenu.settings,
      layout: PageLayout.wide,
      child: Scaffold(
        appBar: AppBar(
          // 1024 이상은 왼쪽 메뉴로 돌아간다.
          automaticallyImplyLeading: getLayoutSize(context) != LayoutSize.expanded,
          // 설정
          title: Text(l10n.menuSettings),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([
                  managers.authManager,
                  managers.effectSettingsManager,
                  managers.lobbyPresenceManager,
                ]),
                builder: _buildGameAndAccount,
              ),
              // 언어
              _buildGroupTitle(l10n.settingsLanguage),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListenableBuilder(listenable: managers.languageManager, builder: _buildLanguages),
              ),
              const SizedBox(height: 20),
              // 정보
              _buildGroupTitle(l10n.settingsInfoGroup),
              ListenableBuilder(listenable: managers.adManager, builder: _buildInfoCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700, color: LightColors.subText),
      ),
    );
  }

  Widget _buildRowTitle(String title) => Text(title, style: const TextStyle(fontSize: AppTextSizes.body));

  Widget _buildGameAndAccount(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final effectSettings = managers.effectSettingsManager;
    final signedIn = managers.authManager.signedIn;
    final hasProfile = managers.authManager.profile != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 대국
        _buildGroupTitle(l10n.settingsGameGroup),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile(
                // 소리
                title: _buildRowTitle(l10n.settingsSound),
                value: effectSettings.soundEnabled,
                onChanged: _onSoundChanged,
              ),
              if (!kIsWeb)
                SwitchListTile(
                  // 진동
                  title: _buildRowTitle(l10n.settingsVibration),
                  value: effectSettings.vibrationEnabled,
                  onChanged: _onVibrationChanged,
                ),
              if (hasProfile) _buildChallengesEnabled(l10n),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (signedIn) ...[
          // 계정
          _buildGroupTitle(l10n.settingsAccountGroup),
          _buildAccountCard(l10n),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// 대국실의 "신청 받기" 스위치와 같은 설정이다. 대국실에 들어가 있으면 그 항목의 값을 보여준다.
  Widget _buildChallengesEnabled(AppLocalizations l10n) {
    final value = managers.lobbyPresenceManager.entry?.challengesEnabled ?? _challengesEnabled;
    return SwitchListTile(
      // 대국 신청 받기
      title: _buildRowTitle(l10n.settingsChallengesEnabled),
      value: value ?? false,
      onChanged: value == null || _changingChallengesEnabled ? null : _onChallengesEnabledChanged,
    );
  }

  Widget _buildAccountCard(AppLocalizations l10n) {
    final signInMethod = repositories.authRepository.getSignInMethod();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (signInMethod != null)
            ListTile(
              minTileHeight: 56,
              // 로그인 방식
              title: _buildRowTitle(l10n.settingsSignInMethod),
              trailing: Text(
                getSignInMethodLabel(l10n, signInMethod),
                style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
              ),
            ),
          ListTile(
            minTileHeight: 56,
            // 로그아웃
            title: _buildRowTitle(l10n.settingsSignOut),
            onTap: _signingOut || _deletingAccount ? null : _onSignOut,
          ),
          ListTile(
            minTileHeight: 56,
            // 회원 탈퇴
            title: _buildRowTitle(l10n.settingsDeleteAccount),
            onTap: _signingOut || _deletingAccount ? null : _onDeleteAccount,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguages(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    return RadioGroup<AppLanguage>(
      groupValue: managers.languageManager.language,
      onChanged: _onLanguageChanged,
      child: Column(
        children: [
          for (final language in AppLanguage.values)
            RadioListTile<AppLanguage>(
              value: language,
              title: Text(getLanguageLabel(l10n, language), style: const TextStyle(fontSize: AppTextSizes.body)),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final version = _version;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 문서 페이지가 생기면(구현 순서 9번) 잇는다.
          ListTile(
            minTileHeight: 56,
            enabled: false,
            // 이용약관
            title: _buildRowTitle(l10n.termsOfService),
          ),
          ListTile(
            minTileHeight: 56,
            enabled: false,
            // 개인정보처리방침
            title: _buildRowTitle(l10n.privacyPolicy),
          ),
          if (managers.adManager.privacyOptionsRequired)
            ListTile(
              minTileHeight: 56,
              // 광고 개인정보 설정
              title: _buildRowTitle(l10n.settingsAdPrivacy),
              trailing: const Icon(Icons.chevron_right),
              onTap: _onAdPrivacy,
            ),
          ListTile(
            minTileHeight: 56,
            // 오픈소스 라이선스
            title: _buildRowTitle(l10n.settingsLicenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: _onLicenses,
          ),
          ListTile(
            minTileHeight: 56,
            // 버전
            title: _buildRowTitle(l10n.settingsVersion),
            trailing: version == null
                ? null
                : Text(
                    version,
                    style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadChallengesEnabled() async {
    final uid = managers.authManager.uid;
    if (uid == null) {
      return;
    }
    try {
      final userPrivate = await repositories.userPrivateRepository.getUserPrivate(uid);
      if (mounted) {
        setState(() {
          _challengesEnabled = userPrivate?.challengesEnabled;
        });
      }
    } catch (error, stackTrace) {
      developer.log('UserPrivateRepository.getUserPrivate 실패', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
        });
      }
    } catch (error, stackTrace) {
      developer.log('PackageInfo.fromPlatform 실패', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _onSoundChanged(bool enabled) async {
    try {
      await managers.effectSettingsManager.updateSoundEnabled(enabled);
    } catch (error, stackTrace) {
      developer.log('EffectSettingsManager.updateSoundEnabled 실패', error: error, stackTrace: stackTrace);
      await _showSaveError();
    }
  }

  Future<void> _onVibrationChanged(bool enabled) async {
    try {
      await managers.effectSettingsManager.updateVibrationEnabled(enabled);
    } catch (error, stackTrace) {
      developer.log('EffectSettingsManager.updateVibrationEnabled 실패', error: error, stackTrace: stackTrace);
      await _showSaveError();
    }
  }

  Future<void> _onChallengesEnabledChanged(bool enabled) async {
    try {
      setState(() {
        _changingChallengesEnabled = true;
      });
      await managers.lobbyPresenceManager.setChallengesEnabled(enabled);
      _challengesEnabled = enabled;
    } catch (error, stackTrace) {
      developer.log('LobbyPresenceManager.setChallengesEnabled 실패', error: error, stackTrace: stackTrace);
      await _showSaveError();
    } finally {
      if (mounted) {
        setState(() {
          _changingChallengesEnabled = false;
        });
      }
    }
  }

  Future<void> _onLanguageChanged(AppLanguage? language) async {
    if (language == null) {
      return;
    }
    try {
      await managers.languageManager.updateLanguage(language);
    } catch (error, stackTrace) {
      developer.log('LanguageManager.updateLanguage 실패', error: error, stackTrace: stackTrace);
      await _showSaveError();
    }
  }

  Future<void> _showSaveError() async {
    if (mounted) {
      // 설정을 저장하지 못했어요. 잠시 후 다시 해 주세요
      await DialogUtils.showMessage(context, message: AppLocalizations.of(context).errorSaveSettings);
    }
  }

  /// 한 번 묻고 로그아웃한 뒤 홈으로 간다. 진행 중인 대국이 있으면 알리고 로그아웃하지 않는다.
  Future<void> _onSignOut() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    if (managers.playerStateManager.gameId != null) {
      // 대국 중에는 로그아웃할 수 없어요
      await DialogUtils.showMessage(context, message: l10n.settingsSignOutInGame);
      return;
    }
    final confirmed = await DialogUtils.showConfirm(
      context,
      // 로그아웃할까요?
      message: l10n.settingsSignOutConfirm,
      // 로그아웃
      confirmLabel: l10n.settingsSignOut,
    );
    if (!confirmed) {
      return;
    }
    try {
      setState(() {
        _signingOut = true;
      });
      await managers.lobbyPresenceManager.leaveBeforeSignOut();
      await managers.authManager.signOut();
      navigator.popUntil(_isFirstRoute);
    } catch (error, stackTrace) {
      developer.log('AuthManager.signOut 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 로그아웃하지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: l10n.errorSignOut);
      }
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  /// 확인을 받고 탈퇴한 뒤 홈으로 간다. 진행 중인 대국이 있으면 알리고 탈퇴하지 않는다(`docs/server.md`의 회원 탈퇴).
  Future<void> _onDeleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    if (managers.playerStateManager.gameId != null) {
      // 대국 중에는 탈퇴할 수 없어요
      await DialogUtils.showMessage(context, message: l10n.settingsDeleteAccountInGame);
      return;
    }
    final confirmed = await DialogUtils.showConfirm(
      context,
      // 탈퇴하면 급수, 전적, 엽전, 산 상품이 없어져요. 남은 엽전은 돌려받을 수 없어요.\n\n30일 뒤 모두 지우고, 그때까지 같은 계정으로 다시 가입할 수 없어요. 되돌리려면 그 안에 {email}로 알려 주세요.\n\n기보는 닉네임 없이 남고, 엽전 내역은 5년 보관해요.
      message: l10n.settingsDeleteAccountConfirm(supportEmail),
      // 탈퇴하기
      confirmLabel: l10n.settingsDeleteAccountButton,
    );
    if (!confirmed) {
      return;
    }
    try {
      setState(() {
        _deletingAccount = true;
      });
      await repositories.authRepository.revokeAppleSignIn();
      await managers.lobbyPresenceManager.leaveBeforeSignOut();
      await managers.playerStateManager.leaveMatching();
      await managers.authManager.deleteAccount();
      if (mounted) {
        // 탈퇴했어요
        await DialogUtils.showMessage(context, message: l10n.settingsDeleteAccountDone);
      }
      navigator.popUntil(_isFirstRoute);
    } catch (error, stackTrace) {
      if (error is AppException && error.code == AppErrorCode.signInCanceled) {
        return;
      }
      developer.log('회원 탈퇴 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 탈퇴하지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorDeleteAccount;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingAccount = false;
        });
      }
    }
  }

  static bool _isFirstRoute(Route<dynamic> route) => route.isFirst;

  Future<void> _onAdPrivacy() async {
    try {
      await managers.adManager.showPrivacyOptions();
    } catch (error, stackTrace) {
      developer.log('AdManager.showPrivacyOptions 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 광고 설정을 열지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: AppLocalizations.of(context).errorAdPrivacy);
      }
    }
  }

  void _onLicenses() {
    final l10n = AppLocalizations.of(context);
    // 장기고
    showLicensePage(context: context, applicationName: l10n.appTitle, applicationVersion: _version);
  }
}

/// 설정의 언어 선택지 이름. 언어 이름은 그 언어로 쓴다.
String getLanguageLabel(AppLocalizations l10n, AppLanguage language) => switch (language) {
  // 기기 설정 따름
  AppLanguage.system => l10n.languageSystem,
  // 한국어
  AppLanguage.ko => l10n.languageKorean,
  // English
  AppLanguage.en => l10n.languageEnglish,
};

/// 설정의 로그인 방식 이름.
String getSignInMethodLabel(AppLocalizations l10n, SignInMethod method) => switch (method) {
  // Google
  SignInMethod.google => l10n.signInMethodGoogle,
  // Apple
  SignInMethod.apple => l10n.signInMethodApple,
  // 이메일
  SignInMethod.email => l10n.signInMethodEmail,
};
