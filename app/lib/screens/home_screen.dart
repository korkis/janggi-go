import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/invite_link_manager.dart';
import '../models/game_enums.dart';
import '../models/spectate_list_entry.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/game_record.dart';
import '../utils/rank_format.dart';
import '../utils/spectate_order.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/rank_progress_bar.dart';
import '../widgets/spectate_card.dart';
import 'create_room_screen.dart';
import 'lobby_screen.dart';
import 'login_flow.dart';
import 'profile_screen.dart';
import 'quick_match_screen.dart';
import 'records_screen.dart';
import 'room_join_flow.dart';
import 'room_screen.dart';
import 'setup_screen.dart';
import 'spectate_list_screen.dart';
import 'spectate_screen.dart';

/// 홈 화면. 지금은 내 카드, 빠른 대국·방 만들기·대국실·기보·내 정보 버튼, 지금 볼 만한 대국, 최근 내 대국과, 개발 빌드에서만
/// 보이는 개발용 대국 카드들을 보여준다.
///
/// 앱의 처음 화면이라 초대 링크로 들어온 방도 여기서 받아 방 대기실로 간다.
///
/// 1024 이상은 두 칸으로 나눈다(`docs/ui.md`의 넓은 화면). 왼쪽 칸에 내 카드와 대국 버튼을 두고, 대국실·기보·내 정보는 왼쪽 메뉴로
/// 간다.
/// 오른쪽 칸에는 "지금 볼 만한 대국"을 2열 카드로 두고 그 아래에 최근 내 대국을, 개발 빌드에서는 그 아래에 개발용 대국 카드를
/// 둔다.
///
/// 개발용 대국과 개발용 온라인 대국은 사용자 기능으로 내보내지 않는다(`docs/plan.md`의 로드맵).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expanded = getLayoutSize(context) == LayoutSize.expanded;
    return AppPage(
      menu: AppMenu.home,
      layout: PageLayout.wide,
      child: Scaffold(
        body: _InviteLinkHandler(child: SafeArea(child: expanded ? _buildWide(context) : _buildNarrow(context))),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          // 장기고
          l10n.appTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        const _ResumeGameButton(),
        const _MyCard(),
        const SizedBox(height: 16),
        const _QuickMatchButton(),
        const SizedBox(height: 12),
        const _RoomButtons(showLobby: true),
        const SizedBox(height: 12),
        const _MenuButtons(),
        const SizedBox(height: 24),
        const _SpectateSection(wide: false),
        const _RecentGamesSection(),
        const SizedBox(height: 16),
        if (!kReleaseMode) const _DevGameCard(),
        if (!kReleaseMode) ...[const SizedBox(height: 16), const _DevOnlineGameCard()],
      ],
    );
  }

  /// 1024 이상의 두 칸 배치. 제목 "장기고"는 왼쪽 메뉴 맨 위에 있다.
  Widget _buildWide(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: LayoutWidths.homeLeftColumn,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(32, 32, 12, 32),
            children: const [
              _ResumeGameButton(),
              _MyCard(),
              SizedBox(height: 16),
              _QuickMatchButton(),
              SizedBox(height: 12),
              _RoomButtons(showLobby: false),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 32, 32, 32),
            children: [
              const _SpectateSection(wide: true),
              const _RecentGamesSection(),
              if (!kReleaseMode) ...[
                const SizedBox(height: 16),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _DevGameCard()),
                    SizedBox(width: 16),
                    Expanded(child: _DevOnlineGameCard()),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 진행 중인 온라인 대국이 있으면(앱이 꺼졌다 켜진 경우 등) 맨 위에 "대국으로 돌아가기"를 보여준다
/// (`docs/screens.md`의 홈). 상차림 화면으로 열고, 상차림이 끝난 대국이면 상차림 화면이 바로 대국 화면으로 넘긴다.
/// 대국은 없고 방에 남아 있으면 "방으로 돌아가기"를 보여준다.
class _ResumeGameButton extends StatelessWidget {
  const _ResumeGameButton();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([managers.authManager, managers.playerStateManager]),
      builder: _buildButton,
    );
  }

  Widget _buildButton(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final gameId = managers.playerStateManager.gameId;
    final roomId = managers.playerStateManager.playerState?.roomId;
    if (managers.authManager.profile == null) {
      return const SizedBox.shrink();
    }
    if (gameId == null) {
      if (roomId == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FilledButton.icon(
          onPressed: () => _onResumeRoom(context, roomId),
          icon: const Icon(Icons.meeting_room),
          // 방으로 돌아가기
          label: Text(l10n.homeResumeRoom),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FilledButton.icon(
        onPressed: () => _onResume(context, gameId),
        icon: const Icon(Icons.play_arrow),
        // 대국으로 돌아가기
        label: Text(l10n.homeResumeGame),
      ),
    );
  }

  void _onResume(BuildContext context, String gameId) {
    Navigator.of(context).push(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
  }

  void _onResumeRoom(BuildContext context, String roomId) {
    Navigator.of(context).push(RoomScreen.createRoute(roomId));
  }
}

/// 지금 볼 만한 대국(`docs/screens.md`의 홈). 관전 목록과 같은 순서로 앞의 몇 대국만 보여준다.
///
/// 1024 미만은 카드를 가로로 넘겨 보고([wide]가 false), 1024 이상은 오른쪽 칸에 2열 카드로 크게 보여준다. 아래쪽 탭이 생기기
/// 전까지 "전체 보기"로 관전 목록에 간다. 홈에 돌아올 때(관전을 마치고) 다시 읽는다.
class _SpectateSection extends StatefulWidget {
  static const _limit = 6;
  static const _narrowCardWidth = 220.0;

  final bool wide;

  const _SpectateSection({required this.wide});

  @override
  State<_SpectateSection> createState() => _SpectateSectionState();
}

class _SpectateSectionState extends State<_SpectateSection> {
  List<({String gameId, SpectateListEntry entry})>? _entries;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                // 지금 볼 만한 대국
                l10n.homeSpectateTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: _onOpenList,
              // 전체 보기
              child: Text(l10n.homeSpectateAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildContent(context),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = _entries;
    if (entries == null && !_failed) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries == null || entries.isEmpty) {
      return Text(
        // 관전 목록을 불러오지 못했어요 / 지금 볼 수 있는 대국이 없어요
        entries == null ? l10n.errorLoadSpectateList : l10n.spectateEmpty,
        style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
      );
    }
    if (widget.wide) {
      return SpectateCardGrid(entries: entries, onOpen: _onOpen);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in entries)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: _SpectateSection._narrowCardWidth,
                child: SpectateCard(entry: item.entry, onTap: () => _onOpen(item.gameId)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadEntries() async {
    try {
      final entries = await repositories.spectateListRepository.getEntries();
      if (mounted) {
        setState(() {
          _entries = sortSpectateEntries(entries).take(_SpectateSection._limit).toList();
          _failed = false;
        });
      }
    } catch (error, stackTrace) {
      developer.log('SpectateListRepository.getEntries 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
    }
  }

  Future<void> _onOpen(String gameId) async {
    await openSpectate(context, gameId);
    if (mounted) {
      await _loadEntries();
    }
  }

  Future<void> _onOpenList() async {
    await SpectateListScreen.open(context);
    if (mounted) {
      await _loadEntries();
    }
  }
}

/// 최근 내 대국(`docs/screens.md`의 홈 5번). 로그인하고 프로필이 있을 때만 보인다.
///
/// 내 기보 목록과 같은 줄로 최근 [_limit]판을 보여주고, 누르면 그 대국을 복기한다. "전체 보기"는 내 기보 목록으로 간다.
/// 대국이 끝나면 대국 서버가 전적을 더하므로 [RankManager.gameCount]가 바뀔 때 다시 읽는다.
class _RecentGamesSection extends StatefulWidget {
  static const _limit = 3;

  const _RecentGamesSection();

  @override
  State<_RecentGamesSection> createState() => _RecentGamesSectionState();
}

class _RecentGamesSectionState extends State<_RecentGamesSection> {
  // 읽은 기보의 주인과 그때의 대국 수. 둘 중 하나가 바뀌면 다시 읽는다.
  String? _loadedUid;
  int? _loadedGameCount;
  List<MyArchivedGame>? _games;
  final _nicknames = <String, String?>{};
  var _failed = false;

  // 프로필이 생기거나 없어지는 것은 [AuthManager]가, 대국 수는 [RankManager]가 알린다.
  final _listenable = Listenable.merge([managers.authManager, managers.rankManager]);

  @override
  void initState() {
    super.initState();
    _listenable.addListener(_onChanged);
    _onChanged();
  }

  @override
  void dispose() {
    _listenable.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadedUid == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // 최근 내 대국
                  l10n.homeRecentGamesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => RecordsScreen.open(context),
                // 전체 보기
                child: Text(l10n.homeRecentGamesAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = _games;
    if (games == null && !_failed) {
      return const Center(child: CircularProgressIndicator());
    }
    if (games == null || games.isEmpty) {
      return Text(
        // 기보를 불러오지 못했어요 / 아직 끝난 대국이 없어요
        games == null ? l10n.errorLoadRecords : l10n.recordsEmpty,
        style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in games)
          RecordTile(
            item: item,
            opponentNickname: _nicknames[item.opponent.uid] ?? l10n.unknownUser,
            onTap: () => openArchivedReview(context, item, _nicknames),
          ),
      ],
    );
  }

  /// 로그인한 사용자나 대국 수가 바뀌면 최근 기보를 다시 읽는다. 프로필이 없으면 숨긴다.
  void _onChanged() {
    final authManager = managers.authManager;
    final uid = authManager.profile == null ? null : authManager.uid;
    final gameCount = managers.rankManager.gameCount;
    if (uid == _loadedUid && gameCount == _loadedGameCount) {
      return;
    }
    final uidChanged = uid != _loadedUid;
    _loadedUid = uid;
    _loadedGameCount = gameCount;
    if (uidChanged) {
      _games = null;
      _nicknames.clear();
    }
    if (uid == null) {
      setState(() {});
      return;
    }
    _loadGames(uid);
  }

  Future<void> _loadGames(String uid) async {
    try {
      setState(() {
        _failed = false;
      });
      final page = await repositories.archivedGameRepository.getArchivedGames(uid, limit: _RecentGamesSection._limit);
      final games = getMyArchivedGames(uid, page);
      await loadNicknames(_nicknames, [for (final item in games) item.opponent.uid]);
      if (mounted && uid == _loadedUid) {
        setState(() {
          _games = games;
        });
      }
    } catch (error, stackTrace) {
      developer.log('최근 내 대국 읽기 실패', error: error, stackTrace: stackTrace);
      if (mounted && uid == _loadedUid) {
        setState(() {
          _failed = true;
        });
      }
    }
  }
}

/// 방 만들기 버튼과 대국실 버튼(`docs/screens.md`의 홈). 대국실은 아래쪽 탭이 생기기 전까지 버튼으로 둔다.
/// 1024 이상은 대국실이 왼쪽 메뉴에 있어 [showLobby]를 끈다.
/// 로그인과 닉네임을 거친 뒤 간다. 이미 방에 있으면 방 만들기 대신 그 방으로 간다.
class _RoomButtons extends StatelessWidget {
  final bool showLobby;

  const _RoomButtons({required this.showLobby});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _onCreateRoom(context),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.add_home),
            // 방 만들기
            label: Text(l10n.homeCreateRoom),
          ),
        ),
        if (showLobby) ...[
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => LobbyScreen.open(context),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.groups),
              // 대국실
              label: Text(l10n.lobbyTitle),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onCreateRoom(BuildContext context) async {
    final ready = await ensureSignedInWithProfile(context, LoginPurpose.createRoom);
    if (!ready || !context.mounted) {
      return;
    }
    final roomId = managers.playerStateManager.playerState?.roomId;
    if (roomId != null) {
      await Navigator.of(context).push(RoomScreen.createRoute(roomId));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const CreateRoomScreen()));
  }
}

/// 기보 버튼과 내 정보 버튼(`docs/screens.md`의 홈). 아래쪽 탭이 생기기 전까지 버튼으로 둔다. 1024 이상은 왼쪽 메뉴에 있어
/// 두지 않는다.
class _MenuButtons extends StatelessWidget {
  const _MenuButtons();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => RecordsScreen.open(context),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.menu_book),
            // 기보
            label: Text(l10n.menuRecords),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => ProfileScreen.open(context),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.person),
            // 내 정보
            label: Text(l10n.menuProfile),
          ),
        ),
      ],
    );
  }
}

/// 초대 링크로 들어온 방을 받아 로그인과 닉네임을 거친 뒤 방 대기실로 간다(`docs/game/matching.md`의 링크).
///
/// 앱을 연 링크, 앱이 켜져 있는 동안 누른 링크, 안드로이드에서 링크로 설치한 뒤 처음 켠 때가 모두 [InviteLinkManager]로 온다.
/// 다른 화면 위에서 링크가 와도 홈이 그 위에 로그인 창과 방 대기실을 띄운다.
///
/// 창 크기가 바뀌어 홈 배치가 바뀌어도 들어가던 방을 놓치지 않게 [child]를 감싸 배치 바깥에 둔다.
class _InviteLinkHandler extends StatefulWidget {
  final Widget child;

  const _InviteLinkHandler({required this.child});

  @override
  State<_InviteLinkHandler> createState() => _InviteLinkHandlerState();
}

class _InviteLinkHandlerState extends State<_InviteLinkHandler> {
  // 링크의 방에 들어가는 중이다. 그동안 온 링크는 끝난 뒤에 받는다.
  var _joining = false;

  @override
  void initState() {
    super.initState();
    managers.inviteLinkManager.addListener(_onInviteLinkChanged);
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
  }

  @override
  void dispose() {
    managers.inviteLinkManager.removeListener(_onInviteLinkChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// 홈이 뜨기 전에 온 링크(앱을 연 링크)를 받는다.
  void _onFirstFrame(Duration timeStamp) {
    _onInviteLinkChanged();
  }

  Future<void> _onInviteLinkChanged() async {
    if (_joining) {
      return;
    }
    try {
      _joining = true;
      while (context.mounted) {
        final roomId = managers.inviteLinkManager.takePendingRoomId();
        if (roomId == null) {
          break;
        }
        await joinRoomAndOpen(context, roomId, LoginPurpose.joinRoom);
      }
    } finally {
      _joining = false;
    }
  }
}

/// 빠른 대국 큰 버튼(`docs/screens.md`의 홈). 로그인과 닉네임을 거친 뒤 빠른 대국 대기 화면으로 간다.
/// 진행 중인 대국이 있으면 대기열 대신 그 대국으로 간다.
class _QuickMatchButton extends StatelessWidget {
  const _QuickMatchButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: () => _onQuickMatch(context),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
      icon: const Icon(Icons.bolt),
      // 빠른 대국
      label: Text(l10n.homeQuickMatch, style: const TextStyle(fontSize: AppTextSizes.title)),
    );
  }

  Future<void> _onQuickMatch(BuildContext context) async {
    final ready = await ensureSignedInWithProfile(context, LoginPurpose.quickMatch);
    if (!ready || !context.mounted) {
      return;
    }
    final gameId = managers.playerStateManager.gameId;
    if (gameId != null) {
      await Navigator.of(context).push(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
      return;
    }
    await Navigator.of(context).push(createGameRoute<void>((context) => const QuickMatchScreen()));
  }
}

class _DevGameCard extends StatelessWidget {
  const _DevGameCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // 개발용 대국
              l10n.homeDevGameTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              // 한 기기에서 초와 한을 번갈아 둬요
              l10n.homeDevGameDescription,
              style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _onStart(context),
              // 시작하기
              child: Text(l10n.homeDevGameStart),
            ),
          ],
        ),
      ),
    );
  }

  void _onStart(BuildContext context) {
    Navigator.of(context).push(createGameRoute<void>((context) => const SetupScreen()));
  }
}

/// 개발용 온라인 대국 카드. 매칭이 생기기 전에 두 계정으로 한 판을 두기 위해 상대 닉네임으로 대국을 바로 만든다.
///
/// 대국은 대국 서버의 개발용 API(`devCreateGame`)가 만들고, 두 사람의 `player_states.gameId`가 생기면 홈에 있던 앱은
/// 상차림으로 넘어간다. 로그인하고 닉네임을 정한 뒤에만 보인다.
class _DevOnlineGameCard extends StatefulWidget {
  const _DevOnlineGameCard();

  @override
  State<_DevOnlineGameCard> createState() => _DevOnlineGameCardState();
}

class _DevOnlineGameCardState extends State<_DevOnlineGameCard> {
  final _opponentController = TextEditingController();
  var _side = SideChoice.random;
  var _creating = false;

  // 이미 연 대국. 같은 대국을 두 번 열지 않는다.
  String? _openedGameId;

  @override
  void initState() {
    super.initState();
    _openedGameId = managers.playerStateManager.gameId;
    managers.playerStateManager.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    managers.playerStateManager.removeListener(_onPlayerStateChanged);
    _opponentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([managers.authManager, managers.playerStateManager]),
      builder: _buildContent,
    );
  }

  Widget _buildContent(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    if (managers.authManager.profile == null) {
      return const SizedBox.shrink();
    }
    // 진행 중인 대국은 맨 위의 "대국으로 돌아가기"로 간다.
    if (managers.playerStateManager.gameId != null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // 개발용 온라인 대국
              l10n.homeDevOnlineTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              // 상대 닉네임을 넣으면 두 계정의 대국을 바로 만들어요
              l10n.homeDevOnlineDescription,
              style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _opponentController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                // 상대 닉네임
                labelText: l10n.homeDevOnlineOpponent,
              ),
            ),
            const SizedBox(height: 12),
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
            FilledButton(
              onPressed: _creating ? null : _onCreate,
              // 대국 만들기
              child: Text(l10n.homeDevOnlineCreate),
            ),
          ],
        ),
      ),
    );
  }

  void _onSideChanged(Set<SideChoice> selected) {
    setState(() {
      _side = selected.single;
    });
  }

  Future<void> _onCreate() async {
    final opponentNickname = _opponentController.text.trim();
    if (opponentNickname.isEmpty) {
      return;
    }
    try {
      setState(() {
        _creating = true;
      });
      await repositories.gameRepository.createDevGame(opponentNickname: opponentNickname, side: _side);
    } catch (error, stackTrace) {
      developer.log('GameRepository.createDevGame 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 대국을 만들지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorCreateGame;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  /// 새 대국이 생기면 홈이 맨 위에 있을 때 상차림으로 간다. 다른 화면에 있으면 홈의 "대국으로 돌아가기"로 간다.
  void _onPlayerStateChanged() {
    final gameId = managers.playerStateManager.gameId;
    if (gameId == null || gameId == _openedGameId || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    _openGame(gameId);
  }

  void _openGame(String gameId) {
    _openedGameId = gameId;
    Navigator.of(context).push(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
  }
}

/// 내 카드. 로그인하지 않았으면 로그인 버튼과 안내를 둔다(`docs/screens.md`의 로그인).
class _MyCard extends StatelessWidget {
  const _MyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListenableBuilder(
          listenable: Listenable.merge([managers.authManager, managers.rankManager, managers.coinManager]),
          builder: _buildContent,
        ),
      ),
    );
  }

  /// 엽전 잔액(`docs/screens.md`의 홈). 아직 읽지 못했으면 비워 둔다.
  Widget _buildCoinBalance(AppLocalizations l10n) {
    final balance = managers.coinManager.balance;
    if (balance == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      // 엽전 330개
      label: l10n.coinBalanceLabel(balance),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.toll, size: 22, color: LightColors.accent),
          const SizedBox(width: 4),
          Text(
            // 330
            l10n.coinBalanceAmount(balance),
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final authManager = managers.authManager;
    final profile = authManager.profile;
    if (authManager.profileLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profile == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            // 로그인하면 급수와 전적이 저장돼요
            l10n.homeLoginGuide,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _onLogin(context),
            // 로그인
            child: Text(l10n.login),
          ),
        ],
      );
    }
    final rankManager = managers.rankManager;
    final rankLevel = rankManager.rankLevel ?? profile.rankLevel;
    final rankProgress = rankManager.rankProgress;
    final winsToNextRank = rankManager.winsToNextRank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(profile.nickname, style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(width: 12),
            _buildCoinBalance(l10n),
          ],
        ),
        Text(
          getRankLabel(l10n, rankLevel),
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
        if (rankProgress != null && rankLevel < maxRankLevel) ...[
          const SizedBox(height: 12),
          RankProgressBar(
            progress: rankProgress,
            color: LightColors.accent,
            trackColor: LightColors.mutedSurface,
            changeColor: LightColors.accent,
          ),
          if (winsToNextRank != null) ...[
            const SizedBox(height: 6),
            Text(
              // 4급까지 약 3승
              l10n.rankWinsToNext(getRankLabel(l10n, rankLevel + 1), winsToNextRank),
              style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
            ),
          ],
        ],
        if (!kReleaseMode) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _onSignOut(context),
              // 로그아웃 (개발용)
              child: Text(l10n.homeDevSignOut),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onLogin(BuildContext context) async {
    await ensureSignedInWithProfile(context, LoginPurpose.home);
  }

  Future<void> _onSignOut(BuildContext context) async {
    try {
      await managers.authManager.signOut();
    } catch (error, stackTrace) {
      developer.log('AuthManager.signOut 실패', error: error, stackTrace: stackTrace);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        // 로그아웃하지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: l10n.errorSignOut);
      }
    }
  }
}
