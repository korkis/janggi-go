import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/room.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/rank_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/room_condition_chips.dart';
import 'create_room_screen.dart';
import 'login_flow.dart';
import 'online_users_tab.dart';
import 'room_join_flow.dart';

/// 대국실(`docs/screens.md`의 대국실). 방 목록과 접속자 두 탭이 있고, 로비 채팅 탭은 구현 순서 11번에 붙인다.
///
/// 접속자 탭은 `configs/app.onlineUsersVisible`이 켜져 있을 때만 보여준다. 꺼져 있으면 탭 없이 방 목록만 보여준다.
///
/// 방 목록은 공개되어 상대를 기다리는 방을 한 번 읽고, 당겨서 새로 읽는다(`docs/dev_rules.md`의 실시간이 아닌 목록).
/// 열린 방이 없을 때의 관전 목록과 AI 대국 버튼(`docs/game/matching.md`의 방 목록)은 관전(10번)과 AI 대국(4단계)이 생기면 넣는다.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  /// 로그인과 닉네임을 거친 뒤 처음 화면(홈) 위에 대국실을 연다. 홈의 대국실 버튼과 왼쪽 메뉴가 같이 쓴다.
  static Future<void> open(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ready = await ensureSignedInWithProfile(context, LoginPurpose.lobby);
    if (!ready) {
      return;
    }
    navigator.popUntil(_isFirstRoute);
    await navigator.push(MaterialPageRoute<void>(builder: (context) => const LobbyScreen()));
  }

  static bool _isFirstRoute(Route<dynamic> route) => route.isFirst;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  List<({String id, Room room})>? _rooms;
  var _loading = false;
  var _failed = false;

  // 들어가는 중인 방. 같은 방을 두 번 누르지 않게 한다.
  String? _joiningRoomId;

  // `configs/app.onlineUsersVisible`. 읽기 전과 읽지 못했을 때는 접속자 탭을 숨긴다.
  var _onlineUsersVisible = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _loadConfig();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rooms = RefreshIndicator(onRefresh: _loadRooms, child: _buildList(context));
    final scaffold = Scaffold(
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
        bottom: _onlineUsersVisible
            ? TabBar(
                tabs: [
                  // 방 목록
                  Tab(text: l10n.lobbyRoomList),
                  // 접속자
                  Tab(text: l10n.lobbyTabUsers),
                ],
              )
            : null,
      ),
      body: SafeArea(child: _onlineUsersVisible ? TabBarView(children: [rooms, const OnlineUsersTab()]) : rooms),
    );
    return AppPage(
      menu: AppMenu.lobby,
      layout: PageLayout.wide,
      child: _onlineUsersVisible ? DefaultTabController(length: 2, child: scaffold) : scaffold,
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rooms = _rooms;
    final children = <Widget>[
      // 탭이 있으면 탭 이름이 제목이다.
      if (!_onlineUsersVisible) ...[
        Text(
          // 방 목록
          l10n.lobbyRoomList,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
      ],
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
      final tiles = [
        for (final entry in rooms)
          _RoomTile(room: entry.room, joining: _joiningRoomId != null, onEnter: () => _onEnter(entry.id)),
      ];
      children.addAll(getLayoutSize(context) == LayoutSize.expanded ? _pairTiles(tiles) : tiles);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: children,
    );
  }

  /// 1024 이상에서 방 목록을 2열로 놓는다.
  List<Widget> _pairTiles(List<Widget> tiles) {
    return [
      for (var i = 0; i < tiles.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 12),
              Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
    ];
  }

  Future<void> _loadConfig() async {
    try {
      final config = await repositories.configRepository.getAppConfig();
      if (mounted) {
        setState(() {
          _onlineUsersVisible = config.onlineUsersVisible;
        });
      }
    } catch (error, stackTrace) {
      // 접속자 탭을 숨긴 채로 방 목록만 보여준다.
      developer.log('ConfigRepository.getAppConfig 실패', error: error, stackTrace: stackTrace);
    }
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
