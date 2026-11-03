import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/user_private.dart';
import '../models/user_profile.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/dialog_utils.dart';
import '../utils/game_record.dart';
import '../utils/rank_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/rank_progress_bar.dart';
import 'block_list_screen.dart';
import 'login_flow.dart';
import 'nickname_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';

/// 내 정보(`docs/screens.md`의 내 정보). 프로필 카드, 전적, 메뉴를 둔다.
///
/// 프로필 카드에는 닉네임과 닉네임 바꾸기 버튼, 급수, 오늘 전적, 다음 급수까지 진행 막대를 둔다. 전적에는 대국 수, 승, 패, 승률과
/// 최근 10판의 승패를 두고, 승패를 누르면 그 대국의 복기로 간다. 메뉴에는 차단 목록과 설정을 둔다. 상점은 그 화면이 생기면 넣는다.
///
/// 급수와 진행은 [RankManager]로 듣고, 전적과 최근 대국은 화면을 열 때 한 번 읽는다(`docs/dev_rules.md`의 실시간이 아닌 목록).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  /// 로그인과 닉네임을 거친 뒤 처음 화면(홈) 위에 내 정보를 연다. 홈과 왼쪽 메뉴가 같이 쓴다.
  static Future<void> open(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ready = await ensureSignedInWithProfile(context, LoginPurpose.profile);
    if (!ready) {
      return;
    }
    navigator.popUntil(_isFirstRoute);
    await navigator.push(MaterialPageRoute<void>(builder: (context) => const ProfileScreen()));
  }

  static bool _isFirstRoute(Route<dynamic> route) => route.isFirst;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 최근 승패로 보여주는 대국 수.
  static const _recentCount = 10;

  // 오늘 전적을 셀 때 읽는 대국의 최대 수.
  static const _todayLimit = 100;

  // 화면을 열 때 읽은 전적. 읽기 전이면 null이다.
  UserStats? _stats;
  List<MyArchivedGame>? _recentGames;
  List<MyArchivedGame>? _todayGames;
  var _failed = false;

  // 최근 대국 상대의 지금 닉네임. 복기 정보 줄에 쓴다.
  final _nicknames = <String, String?>{};

  // 닉네임 바꾸기를 열기 전에 바꿀 수 있는지 확인하는 중이다.
  var _checkingNickname = false;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      menu: AppMenu.profile,
      layout: PageLayout.wide,
      child: Scaffold(
        appBar: AppBar(
          // 내 정보
          title: Text(l10n.menuProfile),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([managers.authManager, managers.rankManager]),
                builder: _buildProfileCard,
              ),
              const SizedBox(height: 16),
              _buildStatsCard(context),
              const SizedBox(height: 16),
              _buildMenuCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final profile = managers.authManager.profile;
    if (profile == null) {
      return const SizedBox.shrink();
    }
    final rankManager = managers.rankManager;
    final rankLevel = rankManager.rankLevel ?? profile.rankLevel;
    final rankProgress = rankManager.rankProgress;
    final winsToNextRank = rankManager.winsToNextRank;
    final todayGames = _todayGames;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    profile.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _checkingNickname ? null : _onEditNickname,
                  // 닉네임 바꾸기
                  tooltip: l10n.profileEditNickname,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            Text(
              getRankLabel(l10n, rankLevel),
              style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
            ),
            if (todayGames != null) ...[
              const SizedBox(height: 4),
              Text(
                // 오늘 2승 1패
                l10n.profileToday(
                  todayGames.where((item) => item.won).length,
                  todayGames.where((item) => !item.won).length,
                ),
                style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
              ),
            ],
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
          ],
        ),
      ),
    );
  }

  /// 전적: 대국 수, 승, 패, 승률과 최근 10판의 승패.
  Widget _buildStatsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // 전적
              l10n.profileStatsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ..._buildStatsContent(context),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _onAllRecords,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.history),
              // 기보 전체 보기
              label: Text(l10n.profileAllRecords),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatsContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stats = _stats;
    final recentGames = _recentGames;
    if (_failed) {
      return [
        Text(
          // 전적을 불러오지 못했어요
          l10n.errorLoadStats,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _loadRecord,
          // 다시 불러오기
          child: Text(l10n.retry),
        ),
      ];
    }
    if (stats == null || recentGames == null) {
      return const [Center(child: CircularProgressIndicator())];
    }
    return [
      Row(
        children: [
          // 대국 수
          _StatBox(label: l10n.profileGames, value: '${stats.games}'),
          // 승
          _StatBox(label: l10n.profileWins, value: '${stats.wins}'),
          // 패
          _StatBox(label: l10n.profileLosses, value: '${stats.losses}'),
          // 승률 / 56%
          _StatBox(label: l10n.profileWinRate, value: l10n.winRateValue(getWinRate(stats.games, stats.wins))),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        // 최근 10판
        l10n.profileRecent,
        style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (recentGames.isEmpty)
        Text(
          // 아직 둔 대국이 없어요
          l10n.profileRecentEmpty,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        )
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in recentGames)
              InkWell(
                onTap: () => openArchivedReview(context, item, _nicknames),
                customBorder: const CircleBorder(),
                child: ResultBadge(won: item.won),
              ),
          ],
        ),
    ];
  }

  Widget _buildMenuCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.block),
            // 차단 목록
            title: Text(l10n.blockListTitle, style: const TextStyle(fontSize: AppTextSizes.body)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _onBlockList,
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.settings_outlined),
            // 설정
            title: Text(l10n.menuSettings, style: const TextStyle(fontSize: AppTextSizes.body)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _onSettings,
          ),
        ],
      ),
    );
  }

  /// 전적(`users.stats`), 최근 10판, 오늘 끝난 대국을 읽는다.
  Future<void> _loadRecord() async {
    final uid = managers.authManager.uid;
    if (uid == null) {
      return;
    }
    try {
      setState(() {
        _failed = false;
      });
      final now = DateTime.now();
      final archivedGames = repositories.archivedGameRepository;
      final (profile, recent, today) = await (
        repositories.userRepository.getUser(uid),
        archivedGames.getArchivedGames(uid, limit: _recentCount),
        archivedGames.getArchivedGames(uid, limit: _todayLimit, endedSince: DateTime(now.year, now.month, now.day)),
      ).wait;
      if (profile == null) {
        throw StateError('프로필이 없습니다');
      }
      final recentGames = getMyArchivedGames(uid, recent);
      await loadNicknames(_nicknames, [for (final item in recentGames) item.opponent.uid]);
      if (mounted) {
        setState(() {
          _stats = profile.stats;
          _recentGames = recentGames;
          _todayGames = getMyArchivedGames(uid, today);
        });
      }
    } catch (error, stackTrace) {
      developer.log('내 전적 읽기 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
    }
  }

  /// 바꿀 수 있는지 확인하고 닉네임 바꾸기를 연다. 7일 제한이나 무료 변경을 이미 쓴 것은 열기 전에 알린다.
  Future<void> _onEditNickname() async {
    final uid = managers.authManager.uid;
    if (uid == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    UserPrivate? userPrivate;
    try {
      setState(() {
        _checkingNickname = true;
      });
      userPrivate = await repositories.userPrivateRepository.getUserPrivate(uid);
    } catch (error, stackTrace) {
      developer.log('UserPrivateRepository.getUserPrivate 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 닉네임을 바꾸지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: l10n.errorChangeNickname);
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _checkingNickname = false;
        });
      }
    }
    if (!mounted) {
      return;
    }
    final blockedMessage = userPrivate == null ? null : _getNicknameChangeBlock(l10n, userPrivate);
    if (blockedMessage != null) {
      await DialogUtils.showMessage(context, message: blockedMessage);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute<bool>(builder: (context) => const NicknameScreen.change()));
    if (changed == true) {
      // 닉네임을 바꿨어요
      messenger.showSnackBar(SnackBar(content: Text(l10n.nicknameChanged)));
    }
  }

  /// 지금 닉네임을 바꿀 수 없으면 그 안내. 바꿀 수 있으면 null.
  String? _getNicknameChangeBlock(AppLocalizations l10n, UserPrivate userPrivate) {
    final changedAt = userPrivate.nicknameChangedAt;
    if (changedAt != null) {
      final availableAt = changedAt.add(const Duration(days: NicknameRules.changeCooldownDays));
      if (DateTime.now().toUtc().isBefore(availableAt)) {
        // 2026년 11월 10일부터 다시 바꿀 수 있어요
        return l10n.nicknameChangeAvailableAt(availableAt.toLocal());
      }
    }
    if (userPrivate.nicknameChangeCount >= NicknameRules.freeChangeCount) {
      // 무료 닉네임 변경을 이미 썼어요. 다시 바꾸는 기능은 준비 중이에요
      return l10n.errorNicknameChangeNotFree;
    }
    return null;
  }

  Future<void> _onAllRecords() async {
    await RecordsScreen.open(context);
  }

  Future<void> _onBlockList() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const BlockListScreen()));
  }

  Future<void> _onSettings() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const SettingsScreen()));
  }
}

/// [games]판 중 [wins]승의 승률(0~100, 반올림). 둔 대국이 없으면 0이다.
int getWinRate(int games, int wins) => games == 0 ? 0 : (wins * 100 / games).round();

/// 전적의 숫자 하나. 위에 큰 숫자, 아래에 이름을 둔다.
class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: AppTextSizes.large,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          ),
        ],
      ),
    );
  }
}
