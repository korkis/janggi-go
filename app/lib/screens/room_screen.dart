import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/room_manager.dart';
import '../models/game_enums.dart';
import '../models/online_user.dart';
import '../models/room.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/invite_link.dart';
import '../utils/rank_format.dart';
import '../utils/room_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/room_condition_chips.dart';
import 'online_users_tab.dart';
import 'send_challenge_sheet.dart';
import 'setup_screen.dart';

/// 방 대기실(`docs/screens.md`의 방 대기실). 밝은 화면이다.
///
/// `rooms/{roomId}`를 듣고 방장과 상대 자리, 초대 링크, 방장의 내보내기와 대국 시작을 보여준다. 방장이 대국을 시작해 내
/// `player_states.gameId`가 생기면 상차림으로 간다. 대국이 끝나 결과 창을 나가면 이 화면으로 돌아온다. 뒤로 가기는 방 나가기다.
class RoomScreen extends StatefulWidget {
  final String roomId;

  const RoomScreen({super.key, required this.roomId});

  /// 방 대기실 경로 이름. 대국을 마치고 돌아올 때 이 이름으로 찾는다.
  static String getRouteName(String roomId) => '/room/$roomId';

  static MaterialPageRoute<void> createRoute(String roomId) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: getRouteName(roomId)),
      builder: (context) => RoomScreen(roomId: roomId),
    );
  }

  /// 방 대국의 결과 창을 나가 방 대기실로 돌아간다(`docs/game/matching.md`의 방 유지). 아래에 그 방 대기실이 있으면 거기까지
  /// 닫고, 없으면(앱을 다시 켜 홈에서 대국으로 간 경우) 처음 화면까지 닫은 뒤 방 대기실을 연다.
  static void returnTo(NavigatorState navigator, String roomId) {
    final routeName = getRouteName(roomId);
    var found = false;
    navigator.popUntil((route) {
      found = route.settings.name == routeName;
      return found || route.isFirst;
    });
    if (!found) {
      navigator.push(createRoute(roomId));
    }
  }

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final RoomManager _room;

  // 방에 내가 있는 것을 한 번이라도 봤다. 처음 받은 방이 들어오기 전의 캐시일 수 있어 그 전에는 나간 것으로 보지 않는다.
  var _seenMember = false;

  // 이 화면을 떠나기 시작했다(나가기, 방 닫힘, 내보내짐).
  var _exiting = false;

  var _leaving = false;
  var _kicking = false;
  var _starting = false;

  // 이미 연 대국. 같은 대국을 두 번 열지 않는다.
  String? _openedGameId;

  // `configs/app.onlineUsersVisible`. 켜져 있으면 접속자 초대하기를 보여준다. 읽기 전과 읽지 못했을 때는 숨긴다.
  var _onlineUsersVisible = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _room = RoomManager(roomId: widget.roomId);
    _room.addListener(_onRoomChanged);
    _openedGameId = managers.playerStateManager.gameId;
    managers.playerStateManager.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    managers.playerStateManager.removeListener(_onPlayerStateChanged);
    _room.removeListener(_onRoomChanged);
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: AppPage(
        layout: PageLayout.form,
        child: ListenableBuilder(
          listenable: Listenable.merge([_room, managers.playerStateManager]),
          builder: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final room = _room.room;
    final Widget body;
    if (room != null) {
      body = _buildRoom(context, room);
    } else if (_room.failed) {
      body = Center(
        child: Text(
          // 방을 불러오지 못했어요
          l10n.errorLoadRoom,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        // {nickname}의 방
        title: room == null ? null : Text(getRoomTitle(l10n, room)),
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _buildRoom(BuildContext context, Room room) {
    final l10n = AppLocalizations.of(context);
    final handicap = room.handicap;
    final guest = room.guest;
    final host = room.hostUid == managers.authManager.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              RoomConditionChips(room: room),
              if (handicap != null) ...[
                const SizedBox(height: 8),
                Text(
                  // 차, 포 떼기 · 20점 적게 시작
                  getHandicapSummary(l10n, handicap.pieces),
                  style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                ),
              ],
              const SizedBox(height: 20),
              _SeatCard(
                // 방장
                label: l10n.roomHost,
                player: room.host,
              ),
              const SizedBox(height: 12),
              if (guest == null)
                _EmptySeat(
                  // 상대를 기다리고 있어요
                  label: l10n.roomWaitingGuest,
                )
              else
                _SeatCard(
                  // 상대
                  label: l10n.roomGuest,
                  player: guest,
                  trailing: host && room.status == RoomStatus.waiting
                      ? OutlinedButton(
                          onPressed: _kicking ? null : () => _onKick(guest),
                          // 내보내기
                          child: Text(l10n.roomKick),
                        )
                      : null,
                ),
              if (guest == null) ...[const SizedBox(height: 20), _buildInvite(context)],
              if (guest == null && host && _onlineUsersVisible) ...[
                const SizedBox(height: 12),
                _buildInviteUsers(context),
              ],
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: _buildAction(context, room, host)),
      ],
    );
  }

  Widget _buildInvite(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final link = buildInviteLink(widget.roomId).toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // 초대 링크로 부르기
              l10n.roomInviteTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              link,
              style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _onCopyLink(link),
                    icon: const Icon(Icons.copy),
                    // 링크 복사
                    label: Text(l10n.roomCopyLink),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _onShareLink(link),
                    icon: const Icon(Icons.share),
                    // 공유하기
                    label: Text(l10n.roomShareLink),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 접속자 초대하기(`docs/screens.md`의 방 대기실). 대국실 접속자 목록에서 고른 사람에게 이 방으로 신청을 보낸다.
  Widget _buildInviteUsers(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // 접속자 초대하기
              l10n.roomInviteUsers,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              // 대국실에 있는 사람을 골라 이 방으로 불러요
              l10n.roomInviteUsersDescription,
              style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _onInviteUsers,
              icon: const Icon(Icons.person_add),
              // 접속자 초대하기
              label: Text(l10n.roomInviteUsers),
            ),
          ],
        ),
      ),
    );
  }

  /// 아래쪽 버튼. 방장은 대국 시작, 상대는 기다림 안내. 방의 대국이 진행 중이면 대국으로 돌아가기.
  Widget _buildAction(BuildContext context, Room room, bool host) {
    final l10n = AppLocalizations.of(context);
    final gameId = managers.playerStateManager.gameId;
    if (room.status == RoomStatus.playing && gameId != null && gameId == room.gameId) {
      return FilledButton.icon(
        onPressed: () => _openGame(gameId),
        icon: const Icon(Icons.play_arrow),
        // 대국으로 돌아가기
        label: Text(l10n.homeResumeGame),
      );
    }
    if (!host) {
      return Text(
        // 방장이 대국을 시작하면 바로 상차림으로 가요
        l10n.roomWaitingHost,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
      );
    }
    final canStart = room.guestUid != null && room.status == RoomStatus.waiting && !_starting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (room.guestUid == null) ...[
          Text(
            // 상대가 들어오면 시작할 수 있어요
            l10n.roomStartWaiting,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: canStart ? _onStart : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          // 대국 시작
          child: Text(l10n.roomStart),
        ),
      ],
    );
  }

  /// 방이 닫혔거나 내가 방에서 빠졌으면 알리고 나간다.
  void _onRoomChanged() {
    if (!_room.loaded || _exiting || _leaving) {
      return;
    }
    final room = _room.room;
    final uid = managers.authManager.uid;
    final open = room != null && room.status != RoomStatus.closed;
    if (open && (room.hostUid == uid || room.guestUid == uid)) {
      _seenMember = true;
      return;
    }
    if (open && !_seenMember) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final String message;
    if (!open) {
      // 방이 닫혔어요
      message = l10n.roomClosedNotice;
    } else if (room.kickedUids.contains(uid)) {
      // 방장이 내보냈어요
      message = l10n.roomKickedNotice;
    } else {
      // 연결이 오래 끊겨 방에서 나왔어요
      message = l10n.roomRemovedNotice;
    }
    _exit(message);
  }

  /// 이 화면을 닫는다. 맨 위에 있으면 [message]를 알린 뒤 닫고, 대국 화면 아래에 있으면 알리지 않고 이 경로만 뺀다.
  Future<void> _exit(String message) async {
    _exiting = true;
    final route = ModalRoute.of(context);
    if (route == null) {
      return;
    }
    if (!route.isCurrent) {
      Navigator.of(context).removeRoute(route);
      return;
    }
    await DialogUtils.showMessage(context, message: message);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 방장이 대국을 시작해 내 대국이 생기면 이 화면이 맨 위에 있을 때 상차림으로 간다.
  void _onPlayerStateChanged() {
    final gameId = managers.playerStateManager.gameId;
    if (gameId == null || gameId == _openedGameId || _exiting || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    _openGame(gameId);
  }

  void _openGame(String gameId) {
    _openedGameId = gameId;
    Navigator.of(context).push(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    _onLeave();
  }

  /// 방에서 나간다. 방장이면 방이 닫히므로 한 번 더 묻는다.
  Future<void> _onLeave() async {
    if (_leaving || _exiting) {
      return;
    }
    final room = _room.room;
    if (room == null || room.status == RoomStatus.closed) {
      _exiting = true;
      Navigator.of(context).pop();
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (room.hostUid == managers.authManager.uid) {
      final confirmed = await DialogUtils.showConfirm(
        context,
        // 방을 나가면 방이 닫혀요. 나갈까요?
        message: l10n.roomLeaveHostConfirm,
        // 나가기
        confirmLabel: l10n.roomLeave,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    try {
      setState(() {
        _leaving = true;
      });
      await repositories.roomRepository.leaveRoom(widget.roomId);
      _exiting = true;
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error, stackTrace) {
      developer.log('RoomRepository.leaveRoom 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 방을 나가지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorLeaveRoom;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _leaving = false;
        });
      }
    }
  }

  Future<void> _onKick(RoomPlayer guest) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await DialogUtils.showConfirm(
      context,
      // {nickname}님을 내보낼까요? 이 방에 다시 들어올 수 없어요
      message: l10n.roomKickConfirm(guest.nickname),
      // 내보내기
      confirmLabel: l10n.roomKick,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      setState(() {
        _kicking = true;
      });
      await repositories.roomRepository.kickGuest(widget.roomId);
    } catch (error, stackTrace) {
      developer.log('RoomRepository.kickGuest 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 내보내지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorKickGuest;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _kicking = false;
        });
      }
    }
  }

  Future<void> _onStart() async {
    try {
      setState(() {
        _starting = true;
      });
      await repositories.roomRepository.startRoomGame(widget.roomId);
    } catch (error, stackTrace) {
      developer.log('RoomRepository.startRoomGame 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 대국을 시작하지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorStartRoomGame;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
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
      // 접속자 초대하기를 숨기고 초대 링크만 보여준다.
      developer.log('ConfigRepository.getAppConfig 실패', error: error, stackTrace: stackTrace);
    }
  }

  /// 접속자 목록에서 사람을 고르면 이 방으로 초대를 보내고 응답을 기다린다. 수락하면 상대 자리에 그 사람이 들어온다.
  Future<void> _onInviteUsers() async {
    final picked = await showFormSheet<({String uid, OnlineUser user})>(
      context,
      builder: (context) => const _OnlineUserPickerSheet(),
    );
    if (picked == null || !mounted) {
      return;
    }
    await SendChallengeSheet.show(context, toUid: picked.uid, user: picked.user, roomId: widget.roomId);
  }

  Future<void> _onCopyLink(String link) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: link));
    // 링크를 복사했어요
    messenger.showSnackBar(SnackBar(content: Text(l10n.roomLinkCopied)));
  }

  /// 휴대폰의 공유 창으로 링크를 보낸다. 카카오톡도 공유 창에서 고른다.
  Future<void> _onShareLink(String link) async {
    final l10n = AppLocalizations.of(context);
    try {
      // 장기고에서 장기 한 판 두실래요? {link}
      await SharePlus.instance.share(ShareParams(text: l10n.roomInviteMessage(link)));
    } catch (error, stackTrace) {
      developer.log('SharePlus.share 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 공유하지 못했어요. 링크 복사를 써 주세요
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorShareLink)));
      }
    }
  }
}

/// 방장 또는 상대 자리. 닉네임과 급수를 보여준다.
class _SeatCard extends StatelessWidget {
  final String label;
  final RoomPlayer player;
  final Widget? trailing;

  const _SeatCard({required this.label, required this.player, this.trailing});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trailing = this.trailing;
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
                    label,
                    style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                  ),
                  Text(
                    // {nickname} · {rank}
                    l10n.playerNameWithRank(player.nickname, getRankLabel(l10n, player.rankLevel)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }
}

/// 상대가 없는 빈자리.
class _EmptySeat extends StatelessWidget {
  final String label;

  const _EmptySeat({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LightColors.outline, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty, color: LightColors.subText),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
            ),
          ),
        ],
      ),
    );
  }
}

/// 접속자 초대하기의 고르기 창. 대국실 접속자 목록에서 기다리는 사람을 고르면 그 사람을 돌려주며 닫는다.
class _OnlineUserPickerSheet extends StatelessWidget {
  const _OnlineUserPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: OnlineUsersTab(onPick: (uid, user) => Navigator.of(context).pop((uid: uid, user: user))),
    );
  }
}
