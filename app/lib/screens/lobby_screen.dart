import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/room.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/rank_format.dart';
import '../widgets/room_condition_chips.dart';
import 'create_room_screen.dart';
import 'login_flow.dart';
import 'room_join_flow.dart';

/// 대국실(`docs/screens.md`의 대국실). 지금은 방 목록만 있다. 접속자 탭은 구현 순서 9번, 로비 채팅은 11번에 붙인다.
///
/// 방 목록은 공개되어 상대를 기다리는 방을 한 번 읽고, 당겨서 새로 읽는다(`docs/dev_rules.md`의 실시간이 아닌 목록).
/// 열린 방이 없을 때의 관전 목록과 AI 대국 버튼(`docs/game/matching.md`의 방 목록)은 관전(10번)과 AI 대국(4단계)이 생기면 넣는다.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  List<({String id, Room room})>? _rooms;
  var _loading = false;
  var _failed = false;

  // 들어가는 중인 방. 같은 방을 두 번 누르지 않게 한다.
  String? _joiningRoomId;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        // 대국실
        title: Text(l10n.lobbyTitle),
        actions: [
          IconButton(
            onPressed: _onCreateRoom,
            icon: const Icon(Icons.add),
            // 방 만들기
            tooltip: l10n.homeCreateRoom,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _loadRooms, child: _buildList(context)),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rooms = _rooms;
    final children = <Widget>[
      Text(
        // 방 목록
        l10n.lobbyRoomList,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
    ];
    if (rooms == null && _failed) {
      children.addAll([
        Text(
          // 방 목록을 불러오지 못했어요
          l10n.errorLoadRooms,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _loading ? null : _loadRooms,
          // 다시 불러오기
          child: Text(l10n.retry),
        ),
      ]);
    } else if (rooms == null) {
      children.add(const Center(child: CircularProgressIndicator()));
    } else if (rooms.isEmpty) {
      children.addAll([
        Text(
          // 지금 열린 방이 없어요
          l10n.lobbyEmpty,
          style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          // 방을 만들어 상대를 기다려 보세요
          l10n.lobbyEmptyDescription,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _onCreateRoom,
          // 방 만들기
          child: Text(l10n.homeCreateRoom),
        ),
      ]);
    } else {
      for (final entry in rooms) {
        children.add(_RoomTile(room: entry.room, joining: _joiningRoomId != null, onEnter: () => _onEnter(entry.id)));
      }
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: children,
    );
  }

  Future<void> _loadRooms() async {
    try {
      setState(() {
        _loading = true;
      });
      final rooms = await repositories.roomRepository.getRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _failed = false;
        });
      }
    } catch (error, stackTrace) {
      developer.log('RoomRepository.getRooms 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _onEnter(String roomId) async {
    if (_joiningRoomId != null) {
      return;
    }
    try {
      setState(() {
        _joiningRoomId = roomId;
      });
      await joinRoomAndOpen(context, roomId, LoginPurpose.lobby);
    } finally {
      if (mounted) {
        setState(() {
          _joiningRoomId = null;
        });
      }
    }
    // 방에서 나오면 목록이 바뀌었을 수 있다.
    if (mounted) {
      await _loadRooms();
    }
  }

  Future<void> _onCreateRoom() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const CreateRoomScreen()));
    if (mounted) {
      await _loadRooms();
    }
  }
}

/// 방 목록의 한 줄. 방장 닉네임과 급수, 조건 칩, 입장 버튼(`docs/screens.md`의 대국실).
class _RoomTile extends StatelessWidget {
  final Room room;
  final bool joining;
  final VoidCallback onEnter;

  const _RoomTile({required this.room, required this.joining, required this.onEnter});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // {nickname} · {rank}
                    l10n.playerNameWithRank(room.host.nickname, getRankLabel(l10n, room.host.rankLevel)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  RoomConditionChips(room: room, showListed: false),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: joining ? null : onEnter,
              // 입장
              child: Text(l10n.lobbyEnter),
            ),
          ],
        ),
      ),
    );
  }
}
