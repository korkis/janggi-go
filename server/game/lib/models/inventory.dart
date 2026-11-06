import 'package:json_annotation/json_annotation.dart';

import 'game_enums.dart';

part 'inventory.g.dart';

/// Firestore `inventories/{uid}`. 산 상품과 고른 기물이다(`docs/database.md`). 대국 서버는 대국을 만들 때 읽기만 한다.
///
/// 필드는 앱의 `Inventory`(`app/lib/models/inventory.dart`), Functions의 `Inventory`(`server/functions/src/models/store.ts`)와
/// 일치시킨다. `updatedAt`은 쓰지 않아 선언하지 않는다.
@JsonSerializable(createToJson: false)
class Inventory {
  /// 산 재질. 기본 기물(`plastic`)은 넣지 않는다. 대국 서버가 모르는 재질은 기본 기물로 읽는다.
  @JsonKey(unknownEnumValue: PieceMaterial.plastic)
  final List<PieceMaterial> materials;

  /// 고른 재질.
  @JsonKey(unknownEnumValue: PieceMaterial.plastic)
  final PieceMaterial selectedMaterial;

  const Inventory({required this.materials, required this.selectedMaterial});

  factory Inventory.fromJson(Map<String, dynamic> json) => _$InventoryFromJson(json);
}
