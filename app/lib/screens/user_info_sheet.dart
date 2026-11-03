import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/online_user.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/challenge_format.dart';
import '../utils/dialog_utils.dart';
import '../utils/rank_format.dart';
import '../widgets/adaptive_layout.dart';
import 'send_challenge_sheet.dart';

/// 다른 사용자 정보(`docs/screens.md`의 다른 사용자 정보). 대국실 접속자를 누르면 아래에서 올라오고 1024 이상은 가운데 카드로
/// 띄운다.
///
/// 닉네임, 상태, 급수와 대국 신청(크게), 차단 버튼을 둔다. 대국 수, 승률, 나와의 전적은 전적(구현 순서 12번), 신고는 사용자
/// 신고에 저장할 것이 정해지면(`docs/server.md`의 미정) 넣는다.
class UserInfoSheet extends StatefulWidget {
  final String uid;
  final OnlineUser user;

  const UserInfoSheet({super.key, required this.uid, required this.user});

  static Future<void> show(BuildContext context, {required String uid, required OnlineUser user}) {
    return showFormSheet<void>(
      context,
      builder: (context) => UserInfoSheet(uid: uid, user: user),
    );
  }

  @override
  State<UserInfoSheet> createState() => _UserInfoSheetState();
}

class _UserInfoSheetState extends State<UserInfoSheet> {
  var _blocking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = widget.user;
    final state = OnlineUserState.of(user);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              user.nickname,
              style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  getRankLabel(l10n, user.rankLevel),
                  style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                OnlineStatusLabel(state: state),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: state.isChallengeable ? _onChallenge : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.sports_esports),
              // 대국 신청
              label: Text(l10n.userInfoChallenge),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _blocking ? null : _onBlock,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.block),
              // 차단
              label: Text(l10n.userInfoBlock),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onChallenge() async {
    final navigator = Navigator.of(context);
    final parentContext = navigator.context;
    navigator.pop();
    await SendChallengeSheet.show(parentContext, toUid: widget.uid, user: widget.user);
  }

  /// 확인을 한 번 더 받고 차단한다. 차단한 사람은 접속자 목록에서 사라진다.
  Future<void> _onBlock() async {
    final l10n = AppLocalizations.of(context);
    final nickname = widget.user.nickname;
    final confirmed = await DialogUtils.showConfirm(
      context,
      // {nickname}님을 차단할까요? 이 사람의 메시지와 대국 신청이 보이지 않아요
      message: l10n.blockConfirm(nickname),
      // 차단하기
      confirmLabel: l10n.blockAction,
    );
    final uid = managers.authManager.uid;
    if (!confirmed || !mounted || uid == null) {
      return;
    }
    try {
      setState(() {
        _blocking = true;
      });
      await repositories.userBlockRepository.createBlock(uid, widget.uid);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        // {nickname}님을 차단했어요
        messenger.showSnackBar(SnackBar(content: Text(l10n.blockDone(nickname))));
      }
    } catch (error, stackTrace) {
      developer.log('UserBlockRepository.createBlock 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 차단하지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: l10n.errorBlock);
      }
    } finally {
      if (mounted) {
        setState(() {
          _blocking = false;
        });
      }
    }
  }
}

/// 접속자 상태. 점 색과 글자를 함께 보여준다(`docs/screens.md`의 대국실).
class OnlineStatusLabel extends StatelessWidget {
  final OnlineUserState state;

  const OnlineStatusLabel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = switch (state) {
      OnlineUserState.waiting => LightColors.accent,
      OnlineUserState.playing => LightColors.playingStatus,
      OnlineUserState.notAccepting => LightColors.subText,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          // 기다리는 중 / 대국 중 / 신청 받지 않음
          state.getLabel(l10n),
          style: TextStyle(fontSize: AppTextSizes.body, color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
