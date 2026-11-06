import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../models/challenge.dart';
import '../models/game_enums.dart';
import '../models/online_user.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/rank_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/challenge_time_bar.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/handicap_piece_picker.dart';
import 'sanction_dialog.dart';
import 'setup_screen.dart';
import 'store_screen.dart';

/// 대국 신청 보내기 창(`docs/screens.md`의 대국 신청). 아래에서 올라오고 1024 이상은 가운데 카드로 띄운다.
///
/// 상대 닉네임과 급수, 내 진영(기본 무작위, 접장기면 떼는 쪽이 한), 접장기를 고르고 신청을 보낸다. 방 대기실의 접속자 초대면
/// 조건은 방 조건을 쓰므로 고르지 않는다. 보낸 뒤에는 같은 창에서 응답을 기다린다. 상대가 수락하면 상차림으로 가고(방 초대면 창만
/// 닫는다), 거절하거나 응답하지 않으면 그 사실을 알린다. 기다리는 동안 닫으면 신청을 취소한다.
class SendChallengeSheet extends StatefulWidget {
  final String toUid;
  final OnlineUser user;

  /// 방 대기실의 접속자 초대면 그 방.
  final String? roomId;

  const SendChallengeSheet({super.key, required this.toUid, required this.user, required this.roomId});

  static Future<void> show(BuildContext context, {required String toUid, required OnlineUser user, String? roomId}) {
    return showFormSheet<void>(
      context,
      dismissible: false,
      builder: (context) => SendChallengeSheet(toUid: toUid, user: user, roomId: roomId),
    );
  }

  @override
  State<SendChallengeSheet> createState() => _SendChallengeSheetState();
}

class _SendChallengeSheetState extends State<SendChallengeSheet> {
  var _side = SideChoice.random;
  var _handicapped = false;
  var _remover = HandicapRemover.creator;
  final _pieces = <HandicapPiece>{};

  var _sending = false;
  var _cancelling = false;

  // 보낸 신청. null이면 아직 조건을 고르는 중이다.
  String? _challengeId;
  Challenge? _challenge;
  StreamSubscription<Challenge?>? _subscription;

  // 수락된 신청을 처리했다. 같은 신청으로 두 번 옮겨 가지 않는다.
  var _handledAccept = false;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = widget.user;
    final waiting = _challengeId != null && !_isFinished;
    return PopScope(
      canPop: !waiting,
      onPopInvokedWithResult: _onPopInvoked,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                // 대국 신청 / 접속자 초대하기
                widget.roomId == null ? l10n.challengeTitle : l10n.roomInviteUsers,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                // {nickname} · {rank}
                l10n.playerNameWithRank(user.nickname, getRankLabel(l10n, user.rankLevel)),
                style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              if (_challengeId == null) ..._buildForm(context) else ..._buildWaiting(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roomId = widget.roomId;
    final canSend = !_sending && (roomId != null || !_handicapped || _pieces.isNotEmpty);
    return [
      if (roomId != null)
        Text(
          // {nickname}님을 이 방에 초대해요
          l10n.roomInviteConfirm(widget.user.nickname),
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        )
      else ...[
        Text(
          // 내 진영
          l10n.challengeSide,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_handicapped)
          Text(
            // 떼는 쪽이 한을 잡아요
            l10n.createRoomHandicapSide,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          )
        else
          SegmentedButton<SideChoice>(
            segments: [
              for (final side in SideChoice.values)
                ButtonSegment(
                  value: side,
                  // 초 / 한 / 무작위
                  label: Text(l10n.sideChoiceName(side.name)),
                ),
            ],
            selected: {_side},
            onSelectionChanged: _onSideChanged,
          ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _handicapped,
          onChanged: _onHandicapChanged,
          title: Text(
            // 접장기
            l10n.createRoomHandicap,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            // 한쪽이 기물을 떼고 둬요
            l10n.createRoomHandicapDescription,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          ),
        ),
        if (_handicapped) ...[
          const SizedBox(height: 12),
          Text(
            // 떼는 쪽
            l10n.createRoomRemover,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<HandicapRemover>(
            segments: [
              for (final remover in HandicapRemover.values)
                ButtonSegment(
                  value: remover,
                  // 나 / 상대
                  label: Text(l10n.handicapRemover(remover.name)),
                ),
            ],
            selected: {_remover},
            onSelectionChanged: _onRemoverChanged,
          ),
          const SizedBox(height: 16),
          Text(
            // 뗄 기물
            l10n.createRoomPieces,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          HandicapPiecePicker(selected: _pieces, onToggled: _onPieceToggled),
        ],
      ],
      const SizedBox(height: 24),
      FilledButton(
        onPressed: canSend ? _onSend : null,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        // 초대 보내기 / 신청 보내기
        child: Text(roomId != null ? l10n.roomInviteSubmit : l10n.challengeSubmit),
      ),
    ];
  }

  List<Widget> _buildWaiting(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final challenge = _challenge;
    final finishedMessage = _getFinishedMessage(l10n);
    if (finishedMessage != null) {
      return [
        Text(
          finishedMessage,
          style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _onClose,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          // 닫기
          child: Text(l10n.close),
        ),
      ];
    }
    return [
      Text(
        // 상대의 응답을 기다리고 있어요
        l10n.challengeWaiting,
        style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      if (challenge != null) ChallengeTimeBar(createdAt: challenge.createdAt, expiresAt: challenge.expiresAt),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: _cancelling ? null : _onCancel,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        // 신청 취소
        child: Text(l10n.challengeCancel),
      ),
    ];
  }

  /// 응답을 받아 끝난 신청이다. 수락은 옮겨 가므로 끝난 것으로 보지 않는다.
  bool get _isFinished {
    final status = _challenge?.status;
    return status != null && status != ChallengeStatus.pending && status != ChallengeStatus.accepted;
  }

  /// 끝난 신청의 알림. 끝나지 않았으면 null.
  String? _getFinishedMessage(AppLocalizations l10n) {
    if (!_isFinished) {
      return null;
    }
    return switch (_challenge?.status) {
      // 상대가 신청을 거절했어요
      ChallengeStatus.declined => l10n.challengeDeclined,
      // 상대가 응답하지 않았어요
      ChallengeStatus.expired => l10n.challengeExpired,
      // 신청이 취소됐어요
      _ => l10n.challengeCancelled,
    };
  }

  void _onSideChanged(Set<SideChoice> selected) {
    setState(() {
      _side = selected.single;
    });
  }

  void _onHandicapChanged(bool handicapped) {
    setState(() {
      _handicapped = handicapped;
    });
  }

  void _onRemoverChanged(Set<HandicapRemover> selected) {
    setState(() {
      _remover = selected.single;
    });
  }

  void _onPieceToggled(HandicapPiece piece) {
    setState(() {
      if (!_pieces.remove(piece)) {
        _pieces.add(piece);
      }
    });
  }

  Future<void> _onSend() async {
    try {
      setState(() {
        _sending = true;
      });
      final roomId = widget.roomId;
      final String challengeId;
      if (roomId != null) {
        challengeId = await repositories.challengeRepository.sendRoomInvite(toUid: widget.toUid, roomId: roomId);
      } else {
        challengeId = await repositories.challengeRepository.sendChallenge(
          toUid: widget.toUid,
          senderSide: _handicapped ? null : _side,
          handicapRemover: _handicapped ? _remover : null,
          handicapPieces: _handicapped ? HandicapPiecePicker.getOrderedPieces(_pieces) : null,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _challengeId = challengeId;
      });
      _subscription = repositories.challengeRepository
          .watchChallenge(challengeId)
          .listen(_onChallengeChanged, onError: _onChallengeError);
    } catch (error, stackTrace) {
      developer.log('ChallengeRepository.sendChallenge 실패', error: error, stackTrace: stackTrace);
      if (mounted && !await showSanctionDialogForError(context, error) && mounted) {
        // 신청을 보내지 못했어요. 잠시 후 다시 해 주세요
        await showActionError(context, error: error, fallback: AppLocalizations.of(context).errorSendChallenge);
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _onChallengeChanged(Challenge? challenge) {
    if (!mounted) {
      return;
    }
    setState(() {
      _challenge = challenge;
    });
    if (challenge?.status == ChallengeStatus.accepted) {
      _onAccepted(challenge!);
    }
  }

  void _onChallengeError(Object error, StackTrace stackTrace) {
    developer.log('SendChallengeSheet challenges 듣기 실패', error: error, stackTrace: stackTrace);
  }

  /// 상대가 수락했다. 방 초대면 창만 닫아 방 대기실에서 상대를 보게 하고, 아니면 처음 화면 위에 상차림을 연다.
  void _onAccepted(Challenge challenge) {
    if (_handledAccept) {
      return;
    }
    _handledAccept = true;
    final navigator = Navigator.of(context);
    final gameId = challenge.gameId;
    if (widget.roomId != null || gameId == null) {
      navigator.pop();
      return;
    }
    navigator.popUntil(_isFirstRoute);
    navigator.push(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
  }

  static bool _isFirstRoute(Route<dynamic> route) => route.isFirst;

  Future<void> _onCancel() async {
    final challengeId = _challengeId;
    if (challengeId == null) {
      return;
    }
    try {
      setState(() {
        _cancelling = true;
      });
      await repositories.challengeRepository.cancelChallenge(challengeId);
      if (mounted && _challenge?.status != ChallengeStatus.accepted) {
        Navigator.of(context).pop();
      }
    } catch (error, stackTrace) {
      developer.log('ChallengeRepository.cancelChallenge 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 신청을 취소하지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorCancelChallenge;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _cancelling = false;
        });
      }
    }
  }

  void _onClose() {
    Navigator.of(context).pop();
  }

  /// 기다리는 동안 뒤로 가기는 신청 취소다.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop || _cancelling) {
      return;
    }
    _onCancel();
  }
}
