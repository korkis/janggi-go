import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/game_sounds.dart';
import 'board_geometry.dart';
import 'board_images.dart';
import 'board_painter.dart';
import 'check_effect.dart';
import 'pieces_painter.dart';

/// 장기판. 판과 기물을 [CustomPainter]로 그리고, 누른 교차점을 [onSquareTap]으로 알린다.
///
/// 판은 주어진 공간 안에서 비율을 지키며 가장 크게 그리고, 높이는 판 높이만큼만 차지한다.
/// 장군이면([checkedSide]) 장군 연출을 판 위에 띄운다(`docs/ui.md`의 연출). 장군을 건 수가 판에 들어올 때마다 큰 도장을 찍고,
/// 장군이 풀릴 때까지 장군을 건 기물에 빨간 테두리를 둔다.
class BoardView extends StatefulWidget {
  /// 기물 이동 애니메이션 시간(`docs/ui.md`의 연출). 수를 놓치지 않을 만큼 길고 대국 흐름을 늦추지 않을 만큼 짧다.
  static const moveDuration = Duration(milliseconds: 350);

  final Position position;

  /// true면 한이 아래에 오도록 판을 돌려 그린다.
  final bool flipped;
  final Square? selected;
  final Set<Square> targets;

  /// 마지막으로 둔 수. 바뀌면 그 수의 이동을 애니메이션으로 보여준다.
  final Move? lastMove;

  /// 기물을 살짝 어둡게 그릴 진영.
  final Side? dimmedSide;

  /// 금빛으로 살짝 표시할 자리.
  final Set<Square> highlighted;

  /// 장군을 받은 진영. 장군이 아니면 null이다.
  final Side? checkedSide;

  final ValueChanged<Square>? onSquareTap;
  final PieceMaterial material;

  const BoardView({
    super.key,
    required this.position,
    this.flipped = false,
    this.selected,
    this.targets = const {},
    this.lastMove,
    this.dimmedSide,
    this.highlighted = const {},
    this.checkedSide,
    this.onSquareTap,
    this.material = PieceMaterial.plastic,
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with TickerProviderStateMixin {
  late final AnimationController _moveController;

  // 장군의 큰 도장 연출. 이동 애니메이션과 같은 때 시작한다. 연출 중이 아니면 0이다.
  late final AnimationController _checkController;
  BoardImages? _images;

  /// 이동 애니메이션 중인 수가 잡은 기물.
  Piece? _captured;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(vsync: this, duration: BoardView.moveDuration, value: 1);
    _checkController = AnimationController(vsync: this, duration: BigCheckStamp.duration);
    _images = BoardImages.getLoaded(widget.material);
    if (_images == null) {
      _loadImages();
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.material != widget.material) {
      _loadImages();
    }
    final moved = _startMoveAnimation(oldWidget);
    if (moved && widget.checkedSide != null) {
      // 효과음 파일이 생기면 장군을 걸거나 받을 때 소리를 낸다.
      GameSounds.playCheck();
      if (!MediaQuery.disableAnimationsOf(context)) {
        _checkController.forward(from: 0);
      }
    }
    if (widget.checkedSide == null) {
      _checkController.value = 0;
    }
  }

  /// 이전 국면에서 [BoardView.lastMove]를 둔 경우에만 움직임을 보여준다. 상차림 변경 등으로 국면이 바뀐 경우는 제외한다.
  /// 새 수가 판에 들어왔으면 true다.
  bool _startMoveAnimation(BoardView oldWidget) {
    final move = widget.lastMove;
    if (move == null || move.isPass || move == oldWidget.lastMove || oldWidget.position == widget.position) {
      return false;
    }
    final mover = oldWidget.position.pieceAt(move.from!);
    if (mover == null || widget.position.pieceAt(move.to!) != mover) {
      return false;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _moveController.value = 1;
      return true;
    }
    _captured = oldWidget.position.pieceAt(move.to!);
    _moveController.forward(from: 0);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildBoard);
  }

  Widget _buildBoard(BuildContext context, BoxConstraints constraints) {
    final l10n = AppLocalizations.of(context);
    final size = _boardSizeIn(constraints.biggest);
    final checkedSide = widget.checkedSide;
    // 높이는 판 높이만큼만 차지해서 위아래 정보 줄이 판에 붙게 한다.
    return Center(
      heightFactor: 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.onSquareTap == null ? null : _onTapUp,
        child: SizedBox.fromSize(
          size: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(painter: BoardPainter(background: _images?.board)),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: PiecesPainter(
                    images: _images,
                    position: widget.position,
                    flipped: widget.flipped,
                    selected: widget.selected,
                    targets: widget.targets,
                    lastMove: widget.lastMove,
                    dimmedSide: widget.dimmedSide,
                    highlighted: widget.highlighted,
                    moveProgress: _moveController,
                    captured: _captured,
                  ),
                ),
              ),
              if (checkedSide != null) ...[
                IgnorePointer(
                  child: _CheckerRing(
                    position: widget.position,
                    side: checkedSide,
                    flipped: widget.flipped,
                    moveProgress: _moveController,
                  ),
                ),
                IgnorePointer(
                  // 장군
                  child: BigCheckStamp(progress: _checkController, label: l10n.check, boardSize: size),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onTapUp(TapUpDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    // 누른 자리는 판 기준 좌표로 들어온다.
    final square = BoardGeometry(_boardSizeIn(box.size), flipped: widget.flipped).squareAt(details.localPosition);
    if (square != null) {
      widget.onSquareTap?.call(square);
    }
  }

  /// [available] 안에 비율을 지키며 들어가는 가장 큰 판 크기. 높이가 무한이면 너비에 맞춘다.
  Size _boardSizeIn(Size available) {
    var width = available.width;
    if (available.height.isFinite) {
      width = width.clamp(0.0, available.height * BoardGeometry.aspectRatio);
    }
    return Size(width, width / BoardGeometry.aspectRatio);
  }

  Future<void> _loadImages() async {
    try {
      final images = await BoardImages.load(widget.material);
      if (!mounted) {
        return;
      }
      setState(() => _images = images);
    } catch (error, stackTrace) {
      developer.log('BoardImages.load 실패: ${widget.material.name}', error: error, stackTrace: stackTrace);
    }
  }
}

/// 장군을 건 기물의 빨간 테두리. 기물이 움직여 내려앉은 뒤 나타난다.
class _CheckerRing extends StatelessWidget {
  final Position position;
  final Side side;
  final bool flipped;
  final AnimationController moveProgress;

  const _CheckerRing({required this.position, required this.side, required this.flipped, required this.moveProgress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: moveProgress, builder: _buildRing);
  }

  Widget _buildRing(BuildContext context, Widget? child) {
    if (moveProgress.isAnimating) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: CheckerRingPainter(flipped: flipped, checkers: position.checkingSquares(side)),
    );
  }
}
