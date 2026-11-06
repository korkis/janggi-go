import 'package:json_annotation/json_annotation.dart';

import 'game_enums.dart';

part 'inventory.g.dart';

/// Firestore `inventories/{uid}`. 산 상품과 고른 기물이다(`docs/database.md`). 첫 구매 때 서버가 만든다.
///
/// 필드는 대국 서버의 `Inventory`(`server/game/lib/models/inventory.dart`), Functions의 `Inventory`
/// (`server/functions/src/models/store.ts`)와 일치시킨다.
@JsonSerializable(createToJson: false)
class Inventory {
  final bool adsRemoved;

  /// 산 재질. 기본 기물(`plastic`)은 넣지 않는다. 옛 앱이 모르는 재질은 기본 기물로 읽는다.
  @JsonKey(unknownEnumValue: PieceMaterial.plastic)
  final List<PieceMaterial> materials;

  /// 고른 재질. 앱이 보안 규칙을 거쳐 바꾼다.
  @JsonKey(unknownEnumValue: PieceMaterial.plastic)
  final PieceMaterial selectedMaterial;

  const Inventory({required this.materials, required this.selectedMaterial, required this.adsRemoved});

  factory Inventory.fromJson(Map<String, dynamic> json) => _$InventoryFromJson(json);
}
