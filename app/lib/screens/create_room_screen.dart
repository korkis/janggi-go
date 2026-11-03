import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../models/game_enums.dart';
import '../models/room.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/rank_format.dart';
import '../utils/room_format.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/handicap_piece_picker.dart';
import 'room_screen.dart';

/// 방 만들기(`docs/screens.md`의 방 만들기). 밝은 화면이다. 조건은 `docs/game/matching.md`의 방 만들기를 따른다.
///
/// 내 진영(기본 무작위), 접장기(떼는 쪽과 뗄 기물), 방 목록 공개, 공개 방의 들어올 수 있는 급수를 고른다. "방 만들기"를 누르면
/// 방을 만들고 방 대기실로 간다.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  var _side = SideChoice.random;
  var _handicapped = false;
  var _remover = HandicapRemover.creator;
  final _pieces = <HandicapPiece>{};
  var _listed = true;

  // 들어올 수 있는 급수(rankLevel). 양 끝이 모든 급수면 제한하지 않는다.
  var _rankRange = const RangeValues(1, maxRankLevel + 0.0);

  var _creating = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canCreate = !_creating && (!_handicapped || _pieces.isNotEmpty);
    return AppPage(
      layout: PageLayout.form,
      child: Scaffold(
        appBar: AppBar(
          // 방 만들기
          title: Text(l10n.createRoomTitle),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSide(context),
                    const SizedBox(height: 24),
                    _buildHandicap(context),
                    const SizedBox(height: 24),
                    _buildListed(context),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: FilledButton(
                  onPressed: canCreate ? _onCreate : null,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  // 방 만들기
                  child: Text(l10n.createRoomSubmit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSide(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          // 내 진영
          l10n.createRoomSide,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_handicapped)
          Text(
            // 떼는 쪽이 한을 잡아요
            l10n.createRoomHandicapSide,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          )
        else
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
      ],
    );
  }

  Widget _buildHandicap(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _handicapped,
          onChanged: _onHandicapChanged,
          title: Text(
            // 접장기
            l10n.createRoomHandicap,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            // 한쪽이 기물을 떼고 둬요
            l10n.createRoomHandicapDescription,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          ),
        ),
        if (_handicapped) ...[
          const SizedBox(height: 12),
          Text(
            // 떼는 쪽
            l10n.createRoomRemover,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<HandicapRemover>(
            segments: [
              for (final remover in HandicapRemover.values)
                ButtonSegment(
                  value: remover,
                  // 나 / 상대
                  label: Text(l10n.handicapRemover(remover.name)),
                ),
            ],
            selected: {_remover},
            onSelectionChanged: _onRemoverChanged,
          ),
          const SizedBox(height: 16),
          Text(
            // 뗄 기물
            l10n.createRoomPieces,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          HandicapPiecePicker(selected: _pieces, onToggled: _onPieceToggled),
        ],
      ],
    );
  }

  Widget _buildListed(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final min = _rankRange.start.round();
    final max = _rankRange.end.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _listed,
          onChanged: _onListedChanged,
          title: Text(
            // 방 목록에 공개
            l10n.createRoomListed,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            // 방 목록에 보이고 누구나 들어올 수 있어요 / 초대 링크로만 들어올 수 있어요
            _listed ? l10n.createRoomListedOn : l10n.createRoomListedOff,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          ),
        ),
        if (_listed) ...[
          const SizedBox(height: 12),
          Text(
            // 들어올 수 있는 급수
            l10n.createRoomRankRange,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
          Text(
            // 모든 급수 / 18급 ~ 1단
            getRankRangeLabel(l10n, _getRankRange()),
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.accent, fontWeight: FontWeight.w700),
          ),
          RangeSlider(
            values: _rankRange,
            min: 1,
            max: maxRankLevel + 0.0,
            divisions: maxRankLevel - 1,
            labels: RangeLabels(getRankLabel(l10n, min), getRankLabel(l10n, max)),
            onChanged: _onRankRangeChanged,
          ),
        ],
      ],
    );
  }

  /// 고른 급수 범위. 모든 급수면 null.
  RankRange? _getRankRange() {
    final min = _rankRange.start.round();
    final max = _rankRange.end.round();
    if (min == 1 && max == maxRankLevel) {
      return null;
    }
    return RankRange(min: min, max: max);
  }

  void _onSideChanged(Set<SideChoice> selected) {
    setState(() {
      _side = selected.single;
    });
  }

  void _onHandicapChanged(bool handicapped) {
    setState(() {
      _handicapped = handicapped;
    });
  }

  void _onRemoverChanged(Set<HandicapRemover> selected) {
    setState(() {
      _remover = selected.single;
    });
  }

  void _onPieceToggled(HandicapPiece piece) {
    setState(() {
      if (!_pieces.remove(piece)) {
        _pieces.add(piece);
      }
    });
  }

  void _onListedChanged(bool listed) {
    setState(() {
      _listed = listed;
    });
  }

  void _onRankRangeChanged(RangeValues values) {
    setState(() {
      _rankRange = values;
    });
  }

  Future<void> _onCreate() async {
    try {
      setState(() {
        _creating = true;
      });
      final roomId = await repositories.roomRepository.createRoom(
        hostSide: _side,
        handicapRemover: _handicapped ? _remover : null,
        handicapPieces: _handicapped ? HandicapPiecePicker.getOrderedPieces(_pieces) : null,
        listed: _listed,
        rankRange: _listed ? _getRankRange() : null,
      );
      if (mounted) {
        await Navigator.of(context).pushReplacement(RoomScreen.createRoute(roomId));
      }
    } catch (error, stackTrace) {
      developer.log('RoomRepository.createRoom 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 방을 만들지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorCreateRoom;
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
}
