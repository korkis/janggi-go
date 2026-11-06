import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/challenge.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/challenge_format.dart';
import '../utils/dialog_utils.dart';
import '../utils/rank_format.dart';
import '../widgets/challenge_time_bar.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/room_condition_chips.dart';
import 'room_screen.dart';
import 'sanction_dialog.dart';
import 'setup_screen.dart';
import 'store_screen.dart';

/// 앱의 어느 화면에서든 받은 대국 신청의 수락 팝업을 띄운다(`docs/screens.md`의 대국 신청). `JanggigoApp`이 모든 화면을 감싼다.
///
/// 수락하면 처음 화면 위에 상차림(방 초대면 방 대기실)을 연다. 빠른 대국을 기다리던 중이면 그 화면도 닫는다. 서버가 그 사람을
/// 대기열에서 빼기 때문이다. 받는 사람은 방이나 대국에 있지 않으므로(대국 서버가 그런 사람에게 신청을 전달하지 않는다) 닫히는 화면은
/// 홈, 대국실, 방 만들기, 빠른 대국 대기 같은 화면뿐이다.
class ChallengeListener extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const ChallengeListener({super.key, required this.navigatorKey, required this.child});

  @override
  State<ChallengeListener> createState() => _ChallengeListenerState();
}

class _ChallengeListenerState extends State<ChallengeListener> {
  // 팝업을 띄운 신청. 같은 신청으로 두 번 띄우지 않는다.
  String? _shownChallengeId;

  @override
  void initState() {
    super.initState();
    managers.challengeManager.addListener(_onChallengeChanged);
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
  }

  @override
  void dispose() {
    managers.challengeManager.removeListener(_onChallengeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _onFirstFrame(Duration timeStamp) {
    _onChallengeChanged();
  }

  void _onChallengeChanged() {
    final incoming = managers.challengeManager.incoming;
    if (incoming == null || incoming.id == _shownChallengeId) {
      return;
    }
    _shownChallengeId = incoming.id;
    _showDialog(incoming.id, incoming.challenge);
  }

  Future<void> _showDialog(String challengeId, Challenge challenge) async {
    final context = widget.navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingChallengeDialog(challengeId: challengeId, challenge: challenge),
    );
    if (accepted == true) {
      await _accept(challengeId);
    } else if (accepted == false) {
      await _decline(challengeId);
    }
  }

  Future<void> _accept(String challengeId) async {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.popUntil(_isFirstRoute);
    try {
      final result = await repositories.challengeRepository.respondChallenge(challengeId, accepted: true);
      final roomId = result.roomId;
      final gameId = result.gameId;
      if (roomId != null) {
        await navigator.push(RoomScreen.createRoute(roomId));
      } else if (gameId != null) {
        await navigator.push(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
      }
    } catch (error, stackTrace) {
      developer.log('ChallengeRepository.respondChallenge 실패', error: error, stackTrace: stackTrace);
      await _leaveQuickQueueIfWaiting();
      final context = widget.navigatorKey.currentContext;
      if (context != null && context.mounted && !await showSanctionDialogForError(context, error) && context.mounted) {
        final l10n = AppLocalizations.of(context);
        if (error is AppException && error.code == AppErrorCode.gameNotFound) {
          // 이미 끝난 신청이에요
          await DialogUtils.showMessage(context, message: l10n.challengeEnded);
        } else {
          // 신청에 응답하지 못했어요. 잠시 후 다시 해 주세요
          await showActionError(context, error: error, fallback: l10n.errorRespondChallenge);
        }
      }
    }
  }

  /// 빠른 대국을 기다리다 수락하려 했는데 실패했으면 대기 화면을 이미 닫았으므로 대기열에서도 나온다.
  Future<void> _leaveQuickQueueIfWaiting() async {
    if (managers.playerStateManager.playerState?.quickQueueJoinedAt == null) {
      return;
    }
    try {
      await repositories.gameRepository.leaveQuickQueue();
    } catch (error, stackTrace) {
      developer.log('GameRepository.leaveQuickQueue 실패', error: error, stackTrace: stackTrace);
    }
  }

  /// 거절한다. 이미 끝난 신청이면 서버가 거절하지만 알릴 것이 없으므로 로그만 남긴다.
  Future<void> _decline(String challengeId) async {
    try {
      await repositories.challengeRepository.respondChallenge(challengeId, accepted: false);
    } catch (error, stackTrace) {
      developer.log('ChallengeRepository.respondChallenge 거절 실패', error: error, stackTrace: stackTrace);
    }
  }

  static bool _isFirstRoute(Route<dynamic> route) => route.isFirst;
}

/// 신청 받음 팝업. 신청한 사람의 닉네임과 급수, 조건 칩(접장기, 내 진영, 시간 규칙), 남은 응답 시간 막대, 거절·수락 버튼을 둔다.
///
/// 수락하면 true, 거절하면 false로 닫는다. 응답 시간이 지나거나 보낸 사람이 취소해 서버가 신청 표시를 지우면 null로 닫는다.
class IncomingChallengeDialog extends StatefulWidget {
  final String challengeId;
  final Challenge challenge;

  const IncomingChallengeDialog({super.key, required this.challengeId, required this.challenge});

  @override
  State<IncomingChallengeDialog> createState() => _IncomingChallengeDialogState();
}

class _IncomingChallengeDialogState extends State<IncomingChallengeDialog> {
  var _closed = false;

  @override
  void initState() {
    super.initState();
    managers.challengeManager.addListener(_onChallengeChanged);
  }

  @override
  void dispose() {
    managers.challengeManager.removeListener(_onChallengeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final challenge = widget.challenge;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: LightColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  // 대국 신청이 왔어요 / 방 초대가 왔어요
                  challenge.roomId == null ? l10n.incomingChallenge : l10n.incomingRoomInvite,
                  style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                ),
                const SizedBox(height: 4),
                Text(
                  // {nickname} · {rank}
                  l10n.playerNameWithRank(challenge.from.nickname, getRankLabel(l10n, challenge.from.rankLevel)),
                  style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final chip in getIncomingChallengeChips(l10n, challenge))
                      chip.handicap
                          ? ConditionChip(
                              label: chip.label,
                              color: LightColors.handicap,
                              background: LightColors.handicapSurface,
                            )
                          : ConditionChip(label: chip.label),
                  ],
                ),
                const SizedBox(height: 20),
                ChallengeTimeBar(createdAt: challenge.createdAt, expiresAt: challenge.expiresAt),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onDecline,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        // 거절
                        child: Text(l10n.challengeDecline),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _onAccept,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        // 수락
                        child: Text(l10n.challengeAccept),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 서버가 이 신청을 끝냈으면(응답 마감, 보낸 사람의 취소) 팝업을 닫는다.
  void _onChallengeChanged() {
    if (managers.challengeManager.incoming?.id != widget.challengeId) {
      _close(null);
    }
  }

  void _onAccept() {
    _close(true);
  }

  void _onDecline() {
    _close(false);
  }

  void _close(bool? accepted) {
    if (_closed || !mounted) {
      return;
    }
    _closed = true;
    Navigator.of(context).pop(accepted);
  }
}
