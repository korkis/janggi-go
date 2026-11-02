import 'dart:ui';

import 'package:janggi_core/janggi_core.dart';

/// 장기판 위 교차점과 화면 좌표 사이의 변환. 길이는 칸 크기(교차점 사이 거리) 기준이다.
final class BoardGeometry {
  /// 바깥 선에서 판 끝까지의 여백(칸 크기의 배수).
  static const marginCells = 0.65;
  static const widthCells = Square.fileCount - 1 + marginCells * 2;
  static const heightCells = Square.rankCount - 1 + marginCells * 2;
  static const aspectRatio = widthCells / heightCells;

  final Size size;

  /// true면 한이 아래에 오도록 판을 돌려 그린다.
  final bool flipped;

  /// 칸 크기(픽셀).
  final double cell;

  BoardGeometry(this.size, {required this.flipped}) : cell = size.width / widthCells;

  /// 화면 기준 열(왼쪽부터 0~8)과 행(위부터 0~9)의 교차점 좌표.
  Offset pointAt(int column, int row) => Offset((marginCells + column) * cell, (marginCells + row) * cell);

  Offset centerOf(Square square) => pointAt(columnOf(square), rowOf(square));

  int columnOf(Square square) => flipped ? Square.fileCount - 1 - square.file : square.file;

  int rowOf(Square square) => flipped ? square.rank : Square.rankCount - 1 - square.rank;

  /// [point]에서 가장 가까운 교차점. 판 밖이면 null이다. 교차점 둘레 칸 전체가 누르는 영역이다.
  Square? squareAt(Offset point) {
    final column = (point.dx / cell - marginCells).round();
    final row = (point.dy / cell - marginCells).round();
    if (column < 0 || column >= Square.fileCount || row < 0 || row >= Square.rankCount) {
      return null;
    }
    final file = flipped ? Square.fileCount - 1 - column : column;
    final rank = flipped ? row : Square.rankCount - 1 - row;
    return Square(file, rank);
  }
}
