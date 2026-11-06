import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:janggi_core/janggi_core.dart';

import '../../models/game_enums.dart';

/// 장기판 배경과 기물 그림. [CustomPainter]가 그릴 수 있게 미리 풀어 둔 이미지다.
final class BoardImages {
  static const _boardAsset = 'assets/boards/wood.webp';
  static final _cache = <BoardMaterials, BoardImages>{};
  static final _pieceCache = <PieceMaterial, Map<Piece, ui.Image>>{};
  static ui.Image? _boardCache;

  final ui.Image board;
  final Map<Piece, ui.Image> pieces;

  const BoardImages({required this.board, required this.pieces});

  /// 진영마다 [materials] 재질인 그림을 읽는다. 한 번 읽은 재질은 다시 읽지 않는다.
  static Future<BoardImages> load(BoardMaterials materials) async {
    final cached = _cache[materials];
    if (cached != null) {
      return cached;
    }
    final board = _boardCache ??= await _decode(_boardAsset);
    final choPieces = await _loadPieces(materials.cho);
    final hanPieces = await _loadPieces(materials.han);
    final pieces = <Piece, ui.Image>{};
    for (final type in PieceType.values) {
      pieces[Piece(Side.cho, type)] = choPieces[Piece(Side.cho, type)]!;
      pieces[Piece(Side.han, type)] = hanPieces[Piece(Side.han, type)]!;
    }
    final images = BoardImages(board: board, pieces: pieces);
    _cache[materials] = images;
    return images;
  }

  /// 이미 읽어 둔 그림. 아직 읽지 않았으면 null이다.
  static BoardImages? getLoaded(BoardMaterials materials) => _cache[materials];

  static Future<Map<Piece, ui.Image>> _loadPieces(PieceMaterial material) async {
    final cached = _pieceCache[material];
    if (cached != null) {
      return cached;
    }
    final pieces = <Piece, ui.Image>{};
    for (final side in Side.values) {
      for (final type in PieceType.values) {
        pieces[Piece(side, type)] = await _decode(getPieceAsset(material, Piece(side, type)));
      }
    }
    _pieceCache[material] = pieces;
    return pieces;
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// `docs/ui.md`의 기물 이미지 경로. 이미지 파일 이름은 엔진의 기물 이름과 일부 다르다.
  static String getPieceAsset(PieceMaterial material, Piece piece) {
    final typeName = switch (piece.type) {
      PieceType.king => 'general',
      PieceType.advisor => 'guard',
      PieceType.elephant => 'elephant',
      PieceType.horse => 'horse',
      PieceType.chariot => 'chariot',
      PieceType.cannon => 'cannon',
      PieceType.soldier => 'soldier',
    };
    return 'assets/pieces/${material.name}/${piece.side.name}_$typeName.png';
  }
}
