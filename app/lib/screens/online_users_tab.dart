import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/online_users_manager.dart';
import '../models/online_user.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/challenge_format.dart';
import '../utils/dialog_utils.dart';
import '../utils/rank_format.dart';
import '../widgets/adaptive_layout.dart';
import 'send_challenge_sheet.dart';
import 'user_info_sheet.dart';

/// 대국실의 접속자 탭(`docs/screens.md`의 대국실). 방 대기실의 접속자 초대하기도 같은 목록을 쓴다.
///
/// 위에 닉네임 검색 칸, 접속자 수, 내 "신청 받기" 스위치를 두고, 한 줄에 닉네임, 급수, 상태를 보여준다. 기다리는 중인 사람을
/// 위로 올리고 그 사람에게만 신청 버튼을 둔다. 나와 내가 차단한 사람은 보여주지 않는다. 줄을 누르면 다른 사용자 정보를 띄운다.
///
/// [onPick]을 주면 접속자 초대하기의 고르기 목록이다. 스위치와 다른 사용자 정보 없이 기다리는 사람을 고르면 [onPick]을 부른다.
class OnlineUsersTab extends StatefulWidget {
  final void Function(String uid, OnlineUser user)? onPick;

  const OnlineUsersTab({super.key, this.onPick});

  @override
  State<OnlineUsersTab> createState() => _OnlineUsersTabState();
}

class _OnlineUsersTabState extends State<OnlineUsersTab> {
  late final OnlineUsersManager _users;
  final _search = TextEditingController();
  var _query = '';
  var _changingChallengesEnabled = false;

  @override
  void initState() {
    super.initState();
    _users = OnlineUsersManager();
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    _users.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_users, managers.blockManager, managers.lobbyPresenceManager]),
      builder: _buildContent,
    );
  }

  Widget _buildContent(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final users = _getVisibleUsers();
    final filtered = [
      for (final entry in users ?? const <MapEntry<String, OnlineUser>>[])
        if (_query.isEmpty || entry.value.nickname.toLowerCase().contains(_query)) entry,
    ];
    final children = <Widget>[
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          // 닉네임 검색
          hintText: l10n.onlineUsersSearch,
        ),
      ),
      const SizedBox(height: 12),
      _buildHeader(context, users?.length),
      const SizedBox(height: 12),
    ];
    if (users == null && _users.failed) {
      children.add(
        Text(
          // 접속자를 불러오지 못했어요
          l10n.errorLoadOnlineUsers,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
      );
    } else if (users == null) {
      children.add(const Center(child: CircularProgressIndicator()));
    } else if (filtered.isEmpty) {
      children.add(
        Text(
          // 지금 접속한 사람이 없어요 / 찾는 닉네임이 없어요
          users.isEmpty ? l10n.onlineUsersEmpty : l10n.onlineUsersNoMatch,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
      );
    } else {
      final tiles = [
        for (final entry in filtered)
          _OnlineUserTile(
            user: entry.value,
            picking: widget.onPick != null,
            onTap: () => _onTap(entry.key, entry.value),
            onChallenge: () => _onChallenge(entry.key, entry.value),
          ),
      ];
      children.addAll(
        getLayoutSize(context) == LayoutSize.expanded && widget.onPick == null ? _pairTiles(tiles) : tiles,
      );
    }
    return ListView(padding: const EdgeInsets.all(20), children: children);
  }

  /// 접속자 수와 내 신청 받기 스위치. 고르기 목록이면 수만 보여준다.
  Widget _buildHeader(BuildContext context, int? count) {
    final l10n = AppLocalizations.of(context);
    final entry = managers.lobbyPresenceManager.entry;
    return Row(
      children: [
        Expanded(
          child: count == null
              ? const SizedBox.shrink()
              : Text(
                  // 접속자 {count}명
                  l10n.onlineUsersCount(count),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
        ),
        if (widget.onPick == null) ...[
          Text(
            // 신청 받기
            l10n.onlineUsersChallengesEnabled,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Switch(
            value: entry?.challengesEnabled ?? false,
            onChanged: entry == null || _changingChallengesEnabled ? null : _onChallengesEnabledChanged,
          ),
        ],
      ],
    );
  }

  /// 1024 이상에서 접속자를 2열로 놓는다.
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

  /// 나와 내가 차단한 사람을 뺀 접속자. 기다리는 중, 신청 받지 않음, 대국 중 순서이고 같으면 닉네임 순서다.
  /// 아직 읽지 못했으면 null.
  List<MapEntry<String, OnlineUser>>? _getVisibleUsers() {
    final users = _users.users;
    if (users == null) {
      return null;
    }
    final myUid = managers.authManager.uid;
    final visible = [
      for (final entry in users.entries)
        if (entry.key != myUid && !managers.blockManager.isBlocked(entry.key)) entry,
    ];
    visible.sort(_compareUsers);
    return visible;
  }

  static int _compareUsers(MapEntry<String, OnlineUser> a, MapEntry<String, OnlineUser> b) {
    final byState = OnlineUserState.of(a.value).index.compareTo(OnlineUserState.of(b.value).index);
    return byState != 0 ? byState : a.value.nickname.compareTo(b.value.nickname);
  }

  void _onSearchChanged() {
    final query = _search.text.trim().toLowerCase();
    if (query == _query) {
      return;
    }
    setState(() {
      _query = query;
    });
  }

  void _onTap(String uid, OnlineUser user) {
    final onPick = widget.onPick;
    if (onPick == null) {
      UserInfoSheet.show(context, uid: uid, user: user);
      return;
    }
    if (OnlineUserState.of(user).isChallengeable) {
      onPick(uid, user);
    }
  }

  void _onChallenge(String uid, OnlineUser user) {
    final onPick = widget.onPick;
    if (onPick != null) {
      onPick(uid, user);
      return;
    }
    SendChallengeSheet.show(context, toUid: uid, user: user);
  }

  Future<void> _onChallengesEnabledChanged(bool enabled) async {
    try {
      setState(() {
        _changingChallengesEnabled = true;
      });
      await managers.lobbyPresenceManager.setChallengesEnabled(enabled);
    } catch (error, stackTrace) {
      developer.log('LobbyPresenceManager.setChallengesEnabled 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 신청 받기를 바꾸지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorChallengesEnabled;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _changingChallengesEnabled = false;
        });
      }
    }
  }
}

/// 접속자 한 줄. 닉네임, 급수, 상태와 기다리는 사람의 신청 버튼(`docs/screens.md`의 대국실).
class _OnlineUserTile extends StatelessWidget {
  final OnlineUser user;

  /// 접속자 초대하기의 고르기 목록이면 버튼을 "초대"로 쓴다.
  final bool picking;
  final VoidCallback onTap;
  final VoidCallback onChallenge;

  const _OnlineUserTile({required this.user, required this.picking, required this.onTap, required this.onChallenge});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = OnlineUserState.of(user);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                      l10n.playerNameWithRank(user.nickname, getRankLabel(l10n, user.rankLevel)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    OnlineStatusLabel(state: state),
                  ],
                ),
              ),
              if (state.isChallengeable) ...[
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onChallenge,
                  // 초대 / 신청
                  child: Text(picking ? l10n.onlineUsersInvite : l10n.onlineUsersChallenge),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
