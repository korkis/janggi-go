import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/game_enums.dart';
import '../repositories/app_repositories.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import 'login_flow.dart';
import 'room_screen.dart';

/// 로그인과 닉네임을 거쳐 [roomId]의 빈자리에 앉고 방 대기실을 연다. 초대 링크와 방 목록이 같이 쓴다.
///
/// 들어가지 못하면 사유를 알린다. 자리가 찬 방이 대국 중이면 그 사실을 알린다(`docs/game/matching.md`의 링크).
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
    final message = await _getJoinErrorMessage(l10n, roomId, error);
    if (context.mounted) {
      await DialogUtils.showMessage(context, message: message);
    }
    return;
  }
  if (context.mounted) {
    await Navigator.of(context).push(RoomScreen.createRoute(roomId));
  }
}

/// 방에 들어가지 못한 사유. 자리가 찼으면 방을 다시 읽어 대국 중인지 본다.
Future<String> _getJoinErrorMessage(AppLocalizations l10n, String roomId, Object error) async {
  if (error is! AppException) {
    // 방에 들어가지 못했어요. 잠시 후 다시 해 주세요
    return l10n.errorJoinRoom;
  }
  if (error.code == AppErrorCode.roomFull) {
    try {
      final room = await repositories.roomRepository.getRoom(roomId);
      if (room?.status == RoomStatus.playing) {
        // 지금 대국 중인 방이에요
        return l10n.errorRoomPlaying;
      }
    } catch (readError, stackTrace) {
      developer.log('RoomRepository.getRoom 실패', error: readError, stackTrace: stackTrace);
    }
  }
  return error.getMessage(l10n);
}
