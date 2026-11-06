import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/spectate_list_entry.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/spectate_order.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/spectate_card.dart';
import 'spectate_screen.dart';

/// 관전 목록(`docs/screens.md`의 관전 목록). 로그인하지 않아도 본다.
///
/// 위에 진행 중인 대국 수를 두고, 대국을 두 줄 바둑판식 카드로 인기 있을 만한 순서([sortSpectateEntries])로 보여준다.
/// 실시간으로 바뀌지 않고, 당기거나 관전에서 돌아오면 다시 읽는다(`docs/dev_rules.md`의 실시간이 아닌 목록).
class SpectateListScreen extends StatefulWidget {
  const SpectateListScreen({super.key});

  /// 처음 화면(홈) 위에 관전 목록을 연다. 아래쪽 탭과 왼쪽 메뉴가 같이 쓴다.
  static Future<void> open(BuildContext context) => openMenuScreen(Navigator.of(context), _build);

  static Widget _build(BuildContext context) => const SpectateListScreen();

  @override
  State<SpectateListScreen> createState() => _SpectateListScreenState();
}

class _SpectateListScreenState extends State<SpectateListScreen> {
  List<({String gameId, SpectateListEntry entry})>? _entries;
  var _loading = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      menu: AppMenu.spectate,
      layout: PageLayout.wide,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          // 관전
          title: Text(l10n.menuSpectate),
        ),
        body: SafeArea(
          child: RefreshIndicator(onRefresh: _loadEntries, child: _buildList(context)),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = _entries;
    final List<Widget> children;
    if (entries == null && _failed) {
      children = [
        Text(
          // 관전 목록을 불러오지 못했어요
          l10n.errorLoadSpectateList,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _loading ? null : _loadEntries,
          // 다시 불러오기
          child: Text(l10n.retry),
        ),
      ];
    } else if (entries == null) {
      children = [const Center(child: CircularProgressIndicator())];
    } else if (entries.isEmpty) {
      children = [
        Text(
          // 지금 볼 수 있는 대국이 없어요
          l10n.spectateEmpty,
          style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          // 대국이 시작되면 여기에 보여요
          l10n.spectateEmptyDescription,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
      ];
    } else {
      children = [
        Text(
          // 진행 중인 대국 12개
          l10n.spectateGameCount(entries.length),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SpectateCardGrid(entries: entries, onOpen: _onOpen),
      ];
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: children,
    );
  }

  Future<void> _loadEntries() async {
    try {
      setState(() {
        _loading = true;
      });
      final entries = await repositories.spectateListRepository.getEntries();
      if (mounted) {
        setState(() {
          _entries = sortSpectateEntries(entries);
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
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _onOpen(String gameId) async {
    await openSpectate(context, gameId);
    // 관전하는 동안 목록이 바뀌었을 수 있다.
    if (mounted) {
      await _loadEntries();
    }
  }
}
