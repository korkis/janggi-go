import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/spectate_list_entry.dart';
import '../repositories/app_repositories.dart';

/// 관전 화면 하나의 관전자 표시와 관전자 수. 관전 화면이 만들고 `dispose()`한다.
///
/// 화면을 열면 `spectators/{gameId}`에 이번 관전의 표시를 쓰고 닫으면 지운다. 연결이 끊기면 걸어 둔 `onDisconnect`가 지운다.
/// 로그인하지 않아도 쓴다. 관전자 수는 대국 서버가 세어 `spectate_list`에 쓴 값을 듣는다(`docs/server.md`의 관전자 수).
/// 대국은 `OnlineGameManager`가 따로 듣는다.
class SpectateManager extends ChangeNotifier {
  final String gameId;

  /// 이번 관전의 표시 ID. 화면을 열 때마다 새로 만든다.
  final String viewerId;

  StreamSubscription<SpectateListEntry?>? _entrySubscription;
  int? _spectatorCount;

  SpectateManager({required this.gameId}) : viewerId = repositories.spectatorRepository.createViewerId() {
    _entrySubscription = repositories.spectateListRepository
        .watchEntry(gameId)
        .listen(_onEntryChanged, onError: _onEntryError);
    _createSpectator();
  }

  @override
  void dispose() {
    _entrySubscription?.cancel();
    _removeSpectator();
    super.dispose();
  }

  /// 관전자 수. 관전 목록에 없는 대국(비공개 방, 상차림 중, 끝난 대국)이면 null이다.
  int? get spectatorCount => _spectatorCount;

  /// 표시를 쓰지 못해도 관전은 그대로 보여준다. 관전자 수에만 빠진다.
  Future<void> _createSpectator() async {
    try {
      await repositories.spectatorRepository.createSpectator(gameId, viewerId);
    } catch (error, stackTrace) {
      developer.log('SpectatorRepository.createSpectator 실패', error: error, stackTrace: stackTrace);
    }
  }

  /// 지우지 못하면 연결이 끊길 때 `onDisconnect`가 지운다.
  Future<void> _removeSpectator() async {
    try {
      await repositories.spectatorRepository.removeSpectator(gameId, viewerId);
    } catch (error, stackTrace) {
      developer.log('SpectatorRepository.removeSpectator 실패', error: error, stackTrace: stackTrace);
    }
  }

  void _onEntryChanged(SpectateListEntry? entry) {
    _spectatorCount = entry?.spectatorCount;
    notifyListeners();
  }

  void _onEntryError(Object error, StackTrace stackTrace) {
    developer.log('SpectateManager 관전 목록 카드 듣기 실패', error: error, stackTrace: stackTrace);
  }
}
