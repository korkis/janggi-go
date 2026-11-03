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
import '../widgets/piece_icon.dart';
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
  /// 뗄 기물의 윗줄. 떼는 쪽이 자기 쪽에서 판을 볼 때 놓이는 순서(차·마·상·상·마·차)다(`docs/screens.md`의 방 만들기).
  static const _backRowPieces = [
    HandicapPiece.leftChariot,
    HandicapPiece.leftHorse,
    HandicapPiece.leftElephant,
    HandicapPiece.rightElephant,
    HandicapPiece.rightHorse,
    HandicapPiece.rightChariot,
  ];

  /// 뗄 기물의 아랫줄. 포 두 개.
  static const _cannonPieces = [HandicapPiece.leftCannon, HandicapPiece.rightCannon];

  static const _pieceSize = 44.0;

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
          _buildPieceRow(_backRowPieces),
          const SizedBox(height: 8),
          _buildPieceRow(_cannonPieces),
          const SizedBox(height: 12),
          Text(
            // 차, 포 떼기 · 20점 적게 시작 / 뗄 기물을 골라 주세요
            _pieces.isEmpty ? l10n.createRoomPiecesHint : getHandicapSummary(l10n, _getSelectedPieces()),
            style: TextStyle(
              fontSize: AppTextSizes.body,
              fontWeight: FontWeight.w700,
              color: _pieces.isEmpty ? LightColors.subText : LightColors.handicap,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPieceRow(List<HandicapPiece> pieces) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final piece in pieces)
          _HandicapPieceButton(
            piece: piece,
            size: _pieceSize,
            selected: _pieces.contains(piece),
            onPressed: () => _onPieceToggled(piece),
          ),
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

  /// 고른 기물을 판에 놓이는 순서대로.
  List<HandicapPiece> _getSelectedPieces() => [
    for (final piece in [..._backRowPieces, ..._cannonPieces])
      if (_pieces.contains(piece)) piece,
  ];

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
        handicapPieces: _handicapped ? _getSelectedPieces() : null,
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

/// 뗄 기물 하나. 고르면 회색과 X 표시로 바뀐다(`docs/game/handicap.md`). 떼는 쪽이 한이므로 한의 기물 그림을 쓴다.
class _HandicapPieceButton extends StatelessWidget {
  final HandicapPiece piece;
  final double size;
  final bool selected;
  final VoidCallback onPressed;

  const _HandicapPieceButton({
    required this.piece,
    required this.size,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      // 왼쪽 차 / 오른쪽 포
      label: l10n.handicapPieceLabel(l10n.boardSideName(piece.side.name), l10n.pieceName(piece.type.name)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: selected ? 0.35 : 1,
                child: ColorFiltered(
                  colorFilter: selected
                      ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: PieceIcon(piece: Piece(Side.han, piece.type), size: size),
                ),
              ),
              if (selected) Icon(Icons.close, size: size * 0.8, color: LightColors.handicap),
            ],
          ),
        ),
      ),
    );
  }
}
