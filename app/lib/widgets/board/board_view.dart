import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import 'board_geometry.dart';
import 'board_images.dart';
import 'board_painter.dart';
import 'pieces_painter.dart';

/// 장기판. 판과 기물을 [CustomPainter]로 그리고, 누른 교차점을 [onSquareTap]으로 알린다.
///
/// 판은 주어진 공간 안에서 비율을 지키며 가장 크게 그리고, 높이는 판 높이만큼만 차지한다.
class BoardView extends StatefulWidget {
  /// 기물 이동 애니메이션 시간. 대국 흐름을 늦추지 않도록 짧게 한다.
  static const moveDuration = Duration(milliseconds: 180);

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
    this.onSquareTap,
    this.material = PieceMaterial.plastic,
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final AnimationController _moveController;
  BoardImages? _images;

  /// 이동 애니메이션 중인 수가 잡은 기물.
  Piece? _captured;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(vsync: this, duration: BoardView.moveDuration, value: 1);
    _images = BoardImages.getLoaded(widget.material);
    if (_images == null) {
      _loadImages();
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.material != widget.material) {
      _loadImages();
    }
    final move = widget.lastMove;
    if (move == null || move.isPass || move == oldWidget.lastMove || oldWidget.position == widget.position) {
      return;
    }
    // 이전 국면에서 이 수를 둔 경우에만 움직임을 보여준다. 상차림 변경 등으로 국면이 바뀐 경우는 제외한다.
    final mover = oldWidget.position.pieceAt(move.from!);
    if (mover == null || widget.position.pieceAt(move.to!) != mover) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _moveController.value = 1;
      return;
    }
    _captured = oldWidget.position.pieceAt(move.to!);
    _moveController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildBoard);
  }

  Widget _buildBoard(BuildContext context, BoxConstraints constraints) {
    final size = _boardSizeIn(constraints.biggest);
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
