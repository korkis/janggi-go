import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:janggi_core/janggi_core.dart';

/// 기물 재질. [name]이 `assets/pieces/` 아래 폴더 이름이다.
enum PieceMaterial { plastic, wood, aluminum }

/// 장기판 배경과 기물 그림. [CustomPainter]가 그릴 수 있게 미리 풀어 둔 이미지다.
final class BoardImages {
  static const _boardAsset = 'assets/boards/wood.webp';
  static final _cache = <PieceMaterial, BoardImages>{};

  final ui.Image board;
  final Map<Piece, ui.Image> pieces;

  const BoardImages({required this.board, required this.pieces});

  /// [material] 재질의 그림을 읽는다. 한 번 읽은 재질은 다시 읽지 않는다.
  static Future<BoardImages> load(PieceMaterial material) async {
    final cached = _cache[material];
    if (cached != null) {
      return cached;
    }
    final images = await _load(material);
    _cache[material] = images;
    return images;
  }

  /// 이미 읽어 둔 그림. 아직 읽지 않았으면 null이다.
  static BoardImages? getLoaded(PieceMaterial material) => _cache[material];

  static Future<BoardImages> _load(PieceMaterial material) async {
    final board = await _decode(_boardAsset);
    final pieces = <Piece, ui.Image>{};
    for (final side in Side.values) {
      for (final type in PieceType.values) {
        pieces[Piece(side, type)] = await _decode(getPieceAsset(material, Piece(side, type)));
      }
    }
    return BoardImages(board: board, pieces: pieces);
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
