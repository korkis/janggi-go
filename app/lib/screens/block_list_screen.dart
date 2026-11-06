import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/dialog_utils.dart';
import '../widgets/adaptive_layout.dart';

/// 차단 목록(`docs/screens.md`의 차단 목록). 한 줄에 닉네임, 차단한 날짜, 차단 풀기 버튼을 둔다.
///
/// 실시간으로 바뀌지 않고 화면을 열 때 한 번 읽는다. 차단을 풀면 그 줄을 지운다.
class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  // 차단한 사람과 그 닉네임. 읽기 전이면 null이다. 프로필이 없어진 사람은 닉네임이 null이다.
  List<({String blockedUid, String? nickname, DateTime createdAt})>? _blocks;
  var _failed = false;

  // 차단을 푸는 중인 사람.
  final _unblocking = <String>{};

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      layout: PageLayout.wide,
      child: Scaffold(
        appBar: AppBar(
          // 차단 목록
          title: Text(l10n.blockListTitle),
        ),
        body: SafeArea(child: _buildList(context)),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blocks = _blocks;
    final children = <Widget>[
      Text(
        // 차단한 사람의 채팅 메시지와 대국 신청은 보이지 않아요
        l10n.blockListGuide,
        style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
      ),
      const SizedBox(height: 16),
    ];
    if (blocks == null && _failed) {
      children.addAll([
        Text(
          // 차단 목록을 불러오지 못했어요
          l10n.errorLoadBlocks,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _loadBlocks,
          // 다시 불러오기
          child: Text(l10n.retry),
        ),
      ]);
    } else if (blocks == null) {
      children.add(const Center(child: CircularProgressIndicator()));
    } else if (blocks.isEmpty) {
      children.add(
        Text(
          // 차단한 사람이 없어요
          l10n.blockListEmpty,
          style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
        ),
      );
    } else {
      for (final block in blocks) {
        children.add(
          _BlockTile(
            // 탈퇴한 사용자
            nickname: block.nickname ?? l10n.deletedUser,
            createdAt: block.createdAt,
            unblocking: _unblocking.contains(block.blockedUid),
            onUnblock: () => _onUnblock(block.blockedUid),
          ),
        );
      }
    }
    return ListView(padding: const EdgeInsets.all(20), children: children);
  }

  Future<void> _loadBlocks() async {
    final uid = managers.authManager.uid;
    if (uid == null) {
      return;
    }
    try {
      setState(() {
        _failed = false;
      });
      final blocks = await repositories.userBlockRepository.getBlocks(uid);
      final profiles = await Future.wait([
        for (final block in blocks) repositories.userRepository.getUser(block.blockedUid),
      ]);
      if (mounted) {
        setState(() {
          _blocks = [
            for (var i = 0; i < blocks.length; i++)
              (blockedUid: blocks[i].blockedUid, nickname: profiles[i]?.nickname, createdAt: blocks[i].createdAt),
          ];
        });
      }
    } catch (error, stackTrace) {
      developer.log('차단 목록 읽기 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
    }
  }

  Future<void> _onUnblock(String blockedUid) async {
    final uid = managers.authManager.uid;
    if (uid == null || _unblocking.contains(blockedUid)) {
      return;
    }
    try {
      setState(() {
        _unblocking.add(blockedUid);
      });
      await repositories.userBlockRepository.deleteBlock(uid, blockedUid);
      if (mounted) {
        setState(() {
          _blocks = [
            for (final block in _blocks ?? const <({String blockedUid, String? nickname, DateTime createdAt})>[])
              if (block.blockedUid != blockedUid) block,
          ];
        });
      }
    } catch (error, stackTrace) {
      developer.log('UserBlockRepository.deleteBlock 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 차단을 풀지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: AppLocalizations.of(context).errorUnblock);
      }
    } finally {
      if (mounted) {
        setState(() {
          _unblocking.remove(blockedUid);
        });
      }
    }
  }
}

class _BlockTile extends StatelessWidget {
  final String nickname;
  final DateTime createdAt;
  final bool unblocking;
  final VoidCallback onUnblock;

  const _BlockTile({
    required this.nickname,
    required this.createdAt,
    required this.unblocking,
    required this.onUnblock,
  });

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
                    nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // 2026년 11월 3일 차단
                    l10n.blockListDate(createdAt.toLocal()),
                    style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: unblocking ? null : onUnblock,
              // 차단 풀기
              child: Text(l10n.blockListUnblock),
            ),
          ],
        ),
      ),
    );
  }
}
