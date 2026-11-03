import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/game_enums.dart';
import '../repositories/app_repositories.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import 'login_flow.dart';
import 'room_screen.dart';
import 'sanction_dialog.dart';
import 'spectate_screen.dart';

/// 로그인과 닉네임을 거쳐 [roomId]의 빈자리에 앉고 방 대기실을 연다. 초대 링크와 방 목록이 같이 쓴다.
///
/// 들어가지 못하면 사유를 알린다. 자리가 찬 방이 대국 중이면 관전을 권한다(`docs/game/matching.md`의 링크). 비공개 방의
/// 대국은 관전 목록에 없으므로 이렇게 링크로 관전한다.
/// 이미 이 방에 있으면 서버가 그대로 성공시키므로 방 대기실로 돌아간다.
Future<void> joinRoomAndOpen(BuildContext context, String roomId, LoginPurpose purpose) async {
  final ready = await ensureSignedInWithProfile(context, purpose);
  if (!ready || !context.mounted) {
    return;
  }
  try {
    await repositories.roomRepository.joinRoom(roomId);
  } catch (error, stackTrace) {
    developer.log('RoomRepository.joinRoom 실패', error: error, stackTrace: stackTrace);
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final playingGameId = await _getPlayingGameId(roomId, error);
    if (!context.mounted) {
      return;
    }
    if (playingGameId != null) {
      await _offerSpectate(context, playingGameId);
      return;
    }
    if (await showSanctionDialogForError(context, error) || !context.mounted) {
      return;
    }
    await DialogUtils.showMessage(context, message: _getJoinErrorMessage(l10n, error));
    return;
  }
  if (context.mounted) {
    await Navigator.of(context).push(RoomScreen.createRoute(roomId));
  }
}

/// 자리가 차서 들어가지 못한 방이 대국 중이면 그 대국 ID. 방을 다시 읽어 본다.
Future<String?> _getPlayingGameId(String roomId, Object error) async {
  if (error is! AppException || error.code != AppErrorCode.roomFull) {
    return null;
  }
  try {
    final room = await repositories.roomRepository.getRoom(roomId);
    return room?.status == RoomStatus.playing ? room?.gameId : null;
  } catch (readError, stackTrace) {
    developer.log('RoomRepository.getRoom 실패', error: readError, stackTrace: stackTrace);
    return null;
  }
}

/// 방에 들어가지 못한 사유.
String _getJoinErrorMessage(AppLocalizations l10n, Object error) {
  if (error is! AppException) {
    // 방에 들어가지 못했어요. 잠시 후 다시 해 주세요
    return l10n.errorJoinRoom;
  }
  return error.getMessage(l10n);
}

/// "지금 대국 중인 방이에요. 관전할까요?"를 묻고 관전 화면을 연다.
Future<void> _offerSpectate(BuildContext context, String gameId) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await DialogUtils.showConfirm(
    context,
    // 지금 대국 중인 방이에요. 관전할까요?
    message: l10n.spectateRoomPlaying,
    // 관전하기
    confirmLabel: l10n.spectateAction,
  );
  if (confirmed && context.mounted) {
    await openSpectate(context, gameId);
  }
}
