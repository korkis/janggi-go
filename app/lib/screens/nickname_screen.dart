import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/nickname_reject_reason.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/rank_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/player_bar.dart';
import 'login_flow.dart';

/// 입력한 닉네임을 쓸 수 있는지 확인한 상태.
enum _NicknameStatus {
  /// 아직 입력하지 않았다.
  empty,
  checking,
  available,
  rejected,

  /// 닉네임 바꾸기에서 지금 쓰는 닉네임을 그대로 넣었다.
  current,

  /// 서버에 묻지 못했다.
  checkFailed,
}

/// 첫 가입의 닉네임 정하기(`docs/screens.md`의 닉네임 정하기). 프로필을 만들면 true를 돌려주며 닫는다.
///
/// 뒤로 가기 버튼을 두지 않는다. 내 정보의 닉네임 바꾸기([changing])도 이 화면을 그대로 쓰고 버튼만 바꾼다. 바꾸기는 뒤로 갈 수
/// 있고, 미리보기에 지금 급수를 보여주며, 바꾸면 true를 돌려주며 닫는다.
class NicknameScreen extends StatefulWidget {
  final LoginPurpose purpose;

  /// 내 정보의 닉네임 바꾸기다.
  final bool changing;

  /// 닉네임 바꾸기에 내는 엽전. 무료 변경이면 null.
  final int? coinCost;

  const NicknameScreen({super.key, required this.purpose}) : changing = false, coinCost = null;

  const NicknameScreen.change({super.key, this.coinCost}) : purpose = LoginPurpose.profile, changing = true;

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  // 처음 가입한 사용자의 급수. 18급이다.
  static const _initialRankLevel = 1;

  final _controller = TextEditingController();
  Timer? _checkTimer;

  // 마지막으로 서버에 물은 확인의 번호. 늦게 온 앞선 응답을 버리는 데 쓴다.
  int _checkSequence = 0;

  _NicknameStatus _status = _NicknameStatus.empty;

  // 쓸 수 없는 이유. [_status]가 rejected이고 앱이 아는 이유일 때만 있다.
  NicknameRejectReason? _rejectReason;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onNicknameChanged);
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _controller.removeListener(_onNicknameChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nickname = _controller.text;
    final startHint = _getStartHint(l10n);
    final changing = widget.changing;
    return PopScope(
      canPop: changing,
      child: AppPage(
        layout: PageLayout.form,
        child: Scaffold(
          appBar: changing
              ? AppBar(
                  // 닉네임 바꾸기
                  title: Text(l10n.profileEditNickname),
                )
              : null,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, changing ? 16 : 48, 20, 20),
                    children: [
                      Text(
                        // 장기판에서 쓸\n이름을 정해 주세요
                        l10n.nicknameTitle,
                        style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w800, height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        // 대국 상대와 관전하는 사람에게 보여요.
                        l10n.nicknameDescription,
                        style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        // 닉네임
                        l10n.nickname,
                        style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        maxLength: NicknameRules.maxLength,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _onSubmitted,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: LightColors.surface,
                          counterText: '',
                          // 3/10
                          suffixText: l10n.nicknameLength(nickname.length, NicknameRules.maxLength),
                          suffixStyle: const TextStyle(fontSize: 15, color: LightColors.subText),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: LightColors.outline, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: LightColors.accent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatus(l10n),
                      Text(
                        // 한글, 영문, 숫자로 2~10자
                        l10n.nicknameRule(NicknameRules.minLength, NicknameRules.maxLength),
                        style: const TextStyle(fontSize: 15, color: LightColors.subText),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        // 대국 화면에서는 이렇게 보여요
                        l10n.nicknamePreviewLabel,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: LightColors.subText),
                      ),
                      const SizedBox(height: 10),
                      _NicknamePreview(nickname: nickname, rankLevel: _getPreviewRankLevel()),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (startHint != null) ...[
                        Text(
                          startHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: LightColors.subText),
                        ),
                        const SizedBox(height: 10),
                      ],
                      FilledButton(
                        onPressed: _canSubmit ? _onSubmit : null,
                        child: _submitting
                            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            // 바꾸기 / 시작하기
                            : Text(changing ? l10n.nicknameChangeSubmit : l10n.nicknameStart),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSubmit => _status == _NicknameStatus.available && !_submitting;

  /// 미리보기의 급수. 첫 가입은 18급, 바꾸기는 지금 급수다.
  int _getPreviewRankLevel() {
    if (!widget.changing) {
      return _initialRankLevel;
    }
    return managers.rankManager.rankLevel ?? _initialRankLevel;
  }

  /// 시작하기 버튼 위에 알리는 이어서 할 일. 이어서 할 일이 없으면 null. 바꾸기는 7일 제한을 알린다.
  String? _getStartHint(AppLocalizations l10n) {
    if (widget.changing) {
      final coinCost = widget.coinCost;
      if (coinCost != null) {
        // 300엽전을 내고 바꿔요. 바꾸면 7일 동안 다시 바꿀 수 없어요
        return l10n.nicknameChangePaidHint(coinCost, NicknameRules.changeCooldownDays);
      }
      // 바꾸면 7일 동안 다시 바꿀 수 없어요
      return l10n.nicknameChangeHint(NicknameRules.changeCooldownDays);
    }
    return _getPurposeHint(l10n);
  }

  String? _getPurposeHint(AppLocalizations l10n) => switch (widget.purpose) {
    LoginPurpose.home => null,
    // 정하고 나면 바로 상대를 찾아요
    LoginPurpose.quickMatch => l10n.nicknameStartHintQuickMatch,
    // 정하고 나면 바로 방을 만들어요
    LoginPurpose.createRoom => l10n.nicknameStartHintCreateRoom,
    // 정하고 나면 대국실로 가요
    LoginPurpose.lobby => l10n.nicknameStartHintLobby,
    // 정하고 나면 바로 방에 들어가요
    LoginPurpose.joinRoom => l10n.nicknameStartHintJoinRoom,
    // 정하고 나면 관전 채팅으로 돌아가요
    LoginPurpose.spectateChat => l10n.nicknameStartHintSpectateChat,
    // 정하고 나면 내 기보로 가요
    LoginPurpose.records => l10n.nicknameStartHintRecords,
    // 정하고 나면 내 정보로 가요
    LoginPurpose.profile => l10n.nicknameStartHintProfile,
  };

  Widget _buildStatus(AppLocalizations l10n) {
    switch (_status) {
      case _NicknameStatus.empty:
        return const SizedBox.shrink();
      case _NicknameStatus.checking:
        return _StatusLine(
          icon: const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          // 확인하고 있어요
          text: l10n.nicknameChecking,
          color: LightColors.subText,
        );
      case _NicknameStatus.available:
        return _StatusLine(
          icon: const Icon(Icons.check, size: 18, color: LightColors.accent),
          // 쓸 수 있는 닉네임이에요
          text: l10n.nicknameAvailable,
          color: LightColors.accent,
        );
      case _NicknameStatus.rejected:
        final reason = _rejectReason;
        return _StatusLine(
          icon: Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error),
          // 쓸 수 없는 닉네임이에요
          text: reason == null
              ? l10n.nicknameUnavailable
              : AppException.fromNicknameRejectReason(reason).getMessage(l10n),
          color: Theme.of(context).colorScheme.error,
        );
      case _NicknameStatus.current:
        return _StatusLine(
          icon: const Icon(Icons.info_outline, size: 18, color: LightColors.subText),
          // 지금 쓰는 닉네임이에요
          text: l10n.nicknameSame,
          color: LightColors.subText,
        );
      case _NicknameStatus.checkFailed:
        return _StatusLine(
          icon: Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error),
          // 확인하지 못했어요. 잠시 후 다시 해 주세요
          text: l10n.nicknameCheckFailed,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }

  void _onNicknameChanged() {
    _checkTimer?.cancel();
    _checkSequence++;
    final nickname = _controller.text;
    if (nickname.isEmpty) {
      setState(() => _status = _NicknameStatus.empty);
      return;
    }
    if (widget.changing && nickname == managers.authManager.profile?.nickname) {
      setState(() => _status = _NicknameStatus.current);
      return;
    }
    if (!NicknameRules.isValidFormat(nickname)) {
      setState(() {
        _status = _NicknameStatus.rejected;
        _rejectReason = NicknameRejectReason.invalidFormat;
      });
      return;
    }
    setState(() => _status = _NicknameStatus.checking);
    _checkTimer = Timer(nicknameCheckDelay, _checkNickname);
  }

  Future<void> _checkNickname() async {
    final sequence = _checkSequence;
    final nickname = _controller.text;
    try {
      final availability = await repositories.userRepository.checkNickname(nickname);
      if (!mounted || sequence != _checkSequence) {
        return;
      }
      setState(() {
        _status = availability.available ? _NicknameStatus.available : _NicknameStatus.rejected;
        _rejectReason = availability.reason;
      });
    } catch (error, stackTrace) {
      developer.log('UserRepository.checkNickname 실패', error: error, stackTrace: stackTrace);
      if (mounted && sequence == _checkSequence) {
        setState(() => _status = _NicknameStatus.checkFailed);
      }
    }
  }

  void _onSubmitted(String _) {
    if (_canSubmit) {
      _onSubmit();
    }
  }

  Future<void> _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    final nickname = _controller.text;
    final coinCost = widget.coinCost;
    if (coinCost != null) {
      final confirmed = await DialogUtils.showConfirm(
        context,
        // 300엽전을 내고 장기신(으)로 바꿀까요?
        message: l10n.nicknameChangeConfirm(coinCost, nickname),
        // 바꾸기
        confirmLabel: l10n.nicknameChangeSubmit,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    try {
      setState(() => _submitting = true);
      if (widget.changing) {
        await managers.authManager.changeNickname(nickname, coinCost: coinCost);
      } else {
        await managers.authManager.createProfile(nickname);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      developer.log('닉네임 정하기·바꾸기 실패', error: error, stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      if (error is AppException &&
          (error.code == AppErrorCode.signupDisabled || error.code == AppErrorCode.signupBlocked)) {
        await _leaveSignup(error.getMessage(l10n));
        return;
      }
      final reason = error is AppException ? _getRejectReason(error.code) : null;
      if (reason != null) {
        setState(() {
          _status = _NicknameStatus.rejected;
          _rejectReason = reason;
        });
        return;
      }
      // 닉네임을 바꾸지 못했어요. 잠시 후 다시 해 주세요 / 닉네임을 정하지 못했어요. 잠시 후 다시 해 주세요
      final fallback = widget.changing ? l10n.errorChangeNickname : l10n.errorCreateProfile;
      final message = error is AppException ? error.getMessage(l10n) : fallback;
      await DialogUtils.showMessage(context, message: message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  /// 가입이 막혔다. 첫 가입 화면에는 뒤로 가기가 없으므로 알린 뒤 로그아웃하고 닫는다.
  Future<void> _leaveSignup(String message) async {
    await DialogUtils.showMessage(context, message: message);
    await managers.authManager.signOut();
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  NicknameRejectReason? _getRejectReason(AppErrorCode code) => switch (code) {
    AppErrorCode.nicknameInvalidFormat => NicknameRejectReason.invalidFormat,
    AppErrorCode.nicknameTaken => NicknameRejectReason.taken,
    AppErrorCode.nicknameBannedWord => NicknameRejectReason.bannedWord,
    AppErrorCode.nicknameImpersonation => NicknameRejectReason.impersonation,
    _ => null,
  };
}

class _StatusLine extends StatelessWidget {
  final Widget icon;
  final String text;
  final Color color;

  const _StatusLine({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// 대국 화면의 내 정보 줄처럼 꾸민 미리보기.
class _NicknamePreview extends StatelessWidget {
  // 미리보기 시계에 보여주는 기본 시간(`docs/game/time.md`의 5분).
  static const _previewClock = '05:00';

  final String nickname;
  final int rankLevel;

  const _NicknamePreview({required this.nickname, required this.rankLevel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: GameColors.background, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const SideAvatar(side: Side.cho, size: 42, active: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTextSizes.body,
                    fontWeight: FontWeight.w700,
                    color: GameColors.text,
                  ),
                ),
                Text(
                  // 18급 · 첫 대국
                  l10n.nicknamePreviewDetail(getRankLabel(l10n, rankLevel)),
                  style: const TextStyle(fontSize: 15, color: GameColors.subText),
                ),
              ],
            ),
          ),
          const Text(
            _previewClock,
            style: TextStyle(
              fontSize: AppTextSizes.large,
              fontWeight: FontWeight.w800,
              color: GameColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
