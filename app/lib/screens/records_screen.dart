import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/game_record.dart';
import '../utils/rank_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/board/board_view.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/handicap_piece_picker.dart';
import 'login_flow.dart';
import 'review_screen.dart';
import 'setup_screen.dart';

/// 내 기보 목록(`docs/screens.md`의 내 기보 목록). 끝난 대국을 날짜별로 묶어 최근 것부터 보여준다.
///
/// 한 줄에 끝난 판 미리보기, 상대와 급수, 결과 종류, 수, 승패를 두고, 누르면 복기로 간다. 위쪽에 "새 판에서 놓아보기" 버튼을 둔다.
/// 실시간으로 바뀌지 않고 화면을 열 때 한 쪽을 읽으며, 맨 아래 "더 보기"로 다음 쪽을 읽는다. 하단 광고 배너 자리는 광고가 생기면
/// 넣는다.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  /// 로그인과 닉네임을 거친 뒤 처음 화면(홈) 위에 내 기보 목록을 연다. 아래쪽 탭과 왼쪽 메뉴, 홈, 내 정보가 같이 쓴다.
  static Future<void> open(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ready = await ensureSignedInWithProfile(context, LoginPurpose.records);
    if (!ready) {
      return;
    }
    await openMenuScreen(navigator, _build);
  }

  static Widget _build(BuildContext context) => const RecordsScreen();

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  // 한 번에 읽는 기보 수.
  static const _pageSize = 20;

  // 읽은 기보. 첫 쪽을 읽기 전이면 null이다.
  List<MyArchivedGame>? _games;

  // 상대의 지금 닉네임. 프로필을 찾지 못한 사람은 null이다.
  final _nicknames = <String, String?>{};

  var _loading = false;
  var _failed = false;

  // 마지막으로 읽은 쪽이 가득 찼다. 다음 쪽이 있을 수 있다.
  var _hasMore = false;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      menu: AppMenu.records,
      layout: PageLayout.wide,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          // 내 기보
          title: Text(l10n.recordsTitle),
        ),
        body: SafeArea(child: _buildList(context)),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = _games;
    final children = <Widget>[
      FilledButton.tonalIcon(
        onPressed: _onFreePlay,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        icon: const Icon(Icons.edit_outlined),
        // 새 판에서 놓아보기
        label: Text(l10n.recordsFreePlay),
      ),
      const SizedBox(height: 20),
    ];
    if (games == null && _failed) {
      children.addAll([
        Text(
          // 기보를 불러오지 못했어요
          l10n.errorLoadRecords,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _loadGames,
          // 다시 불러오기
          child: Text(l10n.retry),
        ),
      ]);
    } else if (games == null) {
      children.add(const Center(child: CircularProgressIndicator()));
    } else if (games.isEmpty) {
      children.add(
        Text(
          // 아직 끝난 대국이 없어요
          l10n.recordsEmpty,
          style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
        ),
      );
    } else {
      _addGameTiles(context, children, games);
      if (_failed) {
        children.add(
          Text(
            // 기보를 불러오지 못했어요
            l10n.errorLoadRecords,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          ),
        );
      }
      if (_hasMore || _failed) {
        children.addAll([
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loading ? null : _loadMore,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            // 다시 불러오기 / 더 보기
            child: Text(_failed ? l10n.retry : l10n.recordsLoadMore),
          ),
        ]);
      }
    }
    return ListView(padding: const EdgeInsets.all(20), children: children);
  }

  /// 기보 줄을 끝난 날짜(오늘, 어제, 날짜)별로 묶어 [children]에 더한다.
  void _addGameTiles(BuildContext context, List<Widget> children, List<MyArchivedGame> games) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? currentDay;
    for (final item in games) {
      final endedAt = item.game.endedAt.toLocal();
      final day = DateTime(endedAt.year, endedAt.month, endedAt.day);
      if (day != currentDay) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: currentDay == null ? 0 : 12, bottom: 8),
            child: Text(
              _getDayLabel(l10n, day, today),
              style: const TextStyle(
                fontSize: AppTextSizes.body,
                fontWeight: FontWeight.w800,
                color: LightColors.subText,
              ),
            ),
          ),
        );
        currentDay = day;
      }
      children.add(
        RecordTile(
          item: item,
          // 탈퇴한 사용자
          opponentNickname: _nicknames[item.opponent.uid] ?? l10n.deletedUser,
          onTap: () => openArchivedReview(context, item, _nicknames),
        ),
      );
    }
  }

  /// 날짜 묶음 제목. 오늘, 어제, 그 앞은 날짜다.
  String _getDayLabel(AppLocalizations l10n, DateTime day, DateTime today) {
    final daysAgo = today.difference(day).inDays;
    if (daysAgo == 0) {
      // 오늘
      return l10n.recordsToday;
    }
    if (daysAgo == 1) {
      // 어제
      return l10n.recordsYesterday;
    }
    // 2026년 11월 1일
    return l10n.recordsDate(day);
  }

  Future<void> _loadGames() async {
    setState(() {
      _games = null;
      _failed = false;
    });
    await _loadPage(endedBefore: null);
  }

  Future<void> _loadMore() async {
    final games = _games;
    if (games == null || games.isEmpty) {
      return;
    }
    await _loadPage(endedBefore: games.last.game.endedAt);
  }

  /// [endedBefore]보다 먼저 끝난 기보 한 쪽을 읽어 뒤에 붙이고 새 상대의 닉네임을 읽는다. null이면 첫 쪽이다.
  Future<void> _loadPage({required DateTime? endedBefore}) async {
    final uid = managers.authManager.uid;
    if (uid == null || _loading) {
      return;
    }
    try {
      setState(() {
        _loading = true;
        _failed = false;
      });
      final page = await repositories.archivedGameRepository.getArchivedGames(
        uid,
        limit: _pageSize,
        endedBefore: endedBefore,
      );
      final games = getMyArchivedGames(uid, page);
      await loadNicknames(_nicknames, [for (final item in games) item.opponent.uid]);
      if (mounted) {
        setState(() {
          _games = [...?_games, ...games];
          _hasMore = page.length == _pageSize;
        });
      }
    } catch (error, stackTrace) {
      developer.log('내 기보 목록 읽기 실패', error: error, stackTrace: stackTrace);
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

  Future<void> _onFreePlay() async {
    final hanRemoved = await showFormSheet<Set<HandicapPiece>>(context, builder: _buildFreePlaySheet);
    if (hanRemoved == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(createGameRoute<void>((context) => SetupScreen.freePlay(hanRemoved: hanRemoved)));
  }

  Widget _buildFreePlaySheet(BuildContext context) => const _FreePlaySheet();
}

/// [uids] 중 [nicknames]에 아직 없는 사람의 지금 닉네임을 읽어 넣는다. 기보에는 닉네임이 없어 `users`에서 읽는다
/// (`docs/database.md`의 `games_archived`). 프로필을 찾지 못한 사람은 null로 넣는다.
Future<void> loadNicknames(Map<String, String?> nicknames, Iterable<String> uids) async {
  final missing = {
    for (final uid in uids)
      if (!nicknames.containsKey(uid)) uid,
  }.toList();
  final profiles = await Future.wait([for (final uid in missing) repositories.userRepository.getUser(uid)]);
  for (var i = 0; i < missing.length; i++) {
    nicknames[missing[i]] = profiles[i]?.nickname;
  }
}

/// [item]의 복기를 연다. 내 진영을 아래에 두고 정보 줄에 지금 닉네임과 대국 시작 때의 급수를 보여준다.
Future<void> openArchivedReview(BuildContext context, MyArchivedGame item, Map<String, String?> nicknames) {
  final l10n = AppLocalizations.of(context);
  final names = (
    cho: _getReviewPlayerName(l10n, item, Side.cho, nicknames),
    han: _getReviewPlayerName(l10n, item, Side.han, nicknames),
  );
  return Navigator.of(
    context,
  ).push(createGameRoute<void>((context) => ReviewScreen(record: item.record, bottomSide: item.mySide, names: names)));
}

/// 복기 정보 줄의 "닉네임 · 4급". 내 닉네임은 지금 프로필에서, 상대 닉네임은 [nicknames]에서 가져온다.
String _getReviewPlayerName(AppLocalizations l10n, MyArchivedGame item, Side side, Map<String, String?> nicknames) {
  final player = item.game.players.get(side);
  final nickname = side == item.mySide ? managers.authManager.profile?.nickname : nicknames[player.uid];
  // {nickname} · {rank} (탈퇴한 사용자)
  return l10n.playerNameWithRank(nickname ?? l10n.deletedUser, getRankLabel(l10n, player.rankLevel));
}

/// 내 기보 한 줄. 끝난 판 미리보기, 상대와 급수, 결과 종류와 수, 승패 표시를 둔다.
class RecordTile extends StatelessWidget {
  static const _previewWidth = 72.0;

  final MyArchivedGame item;
  final String opponentNickname;
  final VoidCallback onTap;

  const RecordTile({super.key, required this.item, required this.opponentNickname, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final won = item.won;
    final reason = item.game.result.reason;
    final String details;
    if (reason == null) {
      // 87수
      details = l10n.recordsMoveCount(item.game.moves.length);
    } else {
      // 외통승 · 87수 / 기권패 · 87수
      details = l10n.recordsDetail(
        won ? l10n.resultReason(reason.name) : l10n.resultReasonLoss(reason.name),
        item.game.moves.length,
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: _previewWidth,
                child: IgnorePointer(
                  child: BoardView(position: item.record.position, flipped: item.mySide == Side.han),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // {nickname} · {rank}
                      l10n.playerNameWithRank(opponentNickname, getRankLabel(l10n, item.opponent.rankLevel)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ResultBadge(won: won),
            ],
          ),
        ),
      ),
    );
  }
}

/// 승패 표시. 이기면 강조색 바탕, 지면 회색 바탕에 글자로 보여준다.
class ResultBadge extends StatelessWidget {
  static const _size = 40.0;

  final bool won;

  const ResultBadge({super.key, required this.won});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: won ? LightColors.accent : LightColors.mutedSurface,
        shape: BoxShape.circle,
        border: won ? null : Border.all(color: LightColors.outline),
      ),
      child: Text(
        // 승 / 패
        won ? l10n.recordsWin : l10n.recordsLoss,
        style: TextStyle(
          fontSize: AppTextSizes.body,
          fontWeight: FontWeight.w800,
          color: won ? LightColors.surface : LightColors.subText,
        ),
      ),
    );
  }
}

/// 새 판에서 놓아보기 창. 접장기면 한에서 뗄 기물을 고르고 상차림 고르기로 간다. 고른 기물을 돌려주며 닫는다.
class _FreePlaySheet extends StatefulWidget {
  const _FreePlaySheet();

  @override
  State<_FreePlaySheet> createState() => _FreePlaySheetState();
}

class _FreePlaySheetState extends State<_FreePlaySheet> {
  final _pieces = <HandicapPiece>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // 새 판에서 놓아보기
              l10n.recordsFreePlay,
              style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              // 접장기로 두려면 한에서 뗄 기물을 골라 주세요
              l10n.freePlayHandicapGuide,
              style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
            ),
            const SizedBox(height: 16),
            HandicapPiecePicker(selected: _pieces, onToggled: _onPieceToggled),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _onStart,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              // 상차림 고르기
              child: Text(l10n.freePlayStart),
            ),
          ],
        ),
      ),
    );
  }

  void _onPieceToggled(HandicapPiece piece) {
    setState(() {
      if (!_pieces.remove(piece)) {
        _pieces.add(piece);
      }
    });
  }

  void _onStart() {
    Navigator.of(context).pop(Set<HandicapPiece>.of(_pieces));
  }
}
