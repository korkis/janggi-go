import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/chat_manager.dart';
import '../models/chat_message.dart';
import '../models/room.dart';
import '../models/spectate_list_entry.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/rank_format.dart';
import '../utils/spectate_order.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/chat_view.dart';
import '../widgets/room_condition_chips.dart';
import '../widgets/spectate_card.dart';
import 'create_room_screen.dart';
import 'login_flow.dart';
import 'online_users_tab.dart';
import 'room_join_flow.dart';
import 'spectate_screen.dart';

/// 대국실(`docs/screens.md`의 대국실). 방 목록, 접속자, 로비 채팅 세 탭이 있다.
///
/// 접속자 탭은 `configs/app.onlineUsersVisible`이 켜져 있을 때만 보여준다. 꺼져 있으면 방 목록과 채팅 두 탭이다.
///
/// 방 목록은 공개되어 상대를 기다리는 방을 한 번 읽고, 당겨서 새로 읽는다(`docs/dev_rules.md`의 실시간이 아닌 목록).
/// 열린 방이 없으면 진행 중인 대국 관전 목록을 대신 보여준다(`docs/game/matching.md`의 방 목록). AI 대국 버튼은 AI 대국(4단계)이
/// 생기면 넣는다.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  /// 로그인과 닉네임을 거친 뒤 처음 화면(홈) 위에 대국실을 연다. 아래쪽 탭과 왼쪽 메뉴가 같이 쓴다.
  static Future<void> open(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ready = await ensureSignedInWithProfile(context, LoginPurpose.lobby);
    if (!ready) {
      return;
    }
    await openMenuScreen(navigator, _build);
  }

  static Widget _build(BuildContext context) => const LobbyScreen();

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  List<({String id, Room room})>? _rooms;
  var _loading = false;
  var _failed = false;

  // 열린 방이 없을 때 대신 보여주는 관전 목록. 읽지 못했으면 비워 둔다.
  List<({String gameId, SpectateListEntry entry})> _spectateEntries = const [];

  // 들어가는 중인 방. 같은 방을 두 번 누르지 않게 한다.
  String? _joiningRoomId;

  // `configs/app.onlineUsersVisible`. 읽기 전과 읽지 못했을 때는 접속자 탭을 숨긴다.
  var _onlineUsersVisible = false;

  // 로비 채팅. 대국실을 연 동안만 듣는다.
  late final ChatManager _chat;

  @override
  void initState() {
    super.initState();
    _chat = ChatManager(
      channel: ChatChannel.lobby,
      authManager: managers.authManager,
      blockManager: managers.blockManager,
    );
    _loadRooms();
    _loadConfig();
  }

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rooms = RefreshIndicator(onRefresh: _loadRooms, child: _buildList(context));
    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
        bottom: TabBar(
          tabs: [
            // 방 목록
            Tab(text: l10n.lobbyRoomList),
            // 접속자
            if (_onlineUsersVisible) Tab(text: l10n.lobbyTabUsers),
            // 채팅
            Tab(text: l10n.chat),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          children: [
            rooms,
            if (_onlineUsersVisible) const OnlineUsersTab(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: ChatView(chats: [_chat], style: ChatStyle.light),
            ),
          ],
        ),
      ),
    );
    return AppPage(
      menu: AppMenu.lobby,
      layout: PageLayout.wide,
      // 접속자 탭이 나타나면 탭 수가 바뀌므로 새 탭 컨트롤러를 만든다.
      child: DefaultTabController(
        key: ValueKey(_onlineUsersVisible),
        length: _onlineUsersVisible ? 3 : 2,
        child: scaffold,
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rooms = _rooms;
    final children = <Widget>[];
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
        if (_spectateEntries.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            // 진행 중인 대국을 구경해 보세요
            l10n.lobbySpectateTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SpectateCardGrid(entries: _spectateEntries, onOpen: _onSpectate),
        ],
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
      if (rooms.isEmpty) {
        await _loadSpectateEntries();
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

  /// 열린 방이 없을 때 대신 보여줄 관전 목록. 읽지 못하면 방이 없다는 안내만 남긴다.
  Future<void> _loadSpectateEntries() async {
    try {
      final entries = await repositories.spectateListRepository.getEntries();
      if (mounted) {
        setState(() {
          _spectateEntries = sortSpectateEntries(entries);
        });
      }
    } catch (error, stackTrace) {
      developer.log('SpectateListRepository.getEntries 실패', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _onSpectate(String gameId) async {
    await openSpectate(context, gameId);
    if (mounted) {
      await _loadRooms();
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
