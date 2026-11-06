// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Inventory _$InventoryFromJson(Map<String, dynamic> json) => $checkedCreate('Inventory', json, ($checkedConvert) {
  final val = Inventory(
    materials: $checkedConvert(
      'materials',
      (v) => (v as List<dynamic>)
          .map((e) => $enumDecode(_$PieceMaterialEnumMap, e, unknownValue: PieceMaterial.plastic))
          .toList(),
    ),
    selectedMaterial: $checkedConvert(
      'selectedMaterial',
      (v) => $enumDecode(_$PieceMaterialEnumMap, v, unknownValue: PieceMaterial.plastic),
    ),
  );
  return val;
});

const _$PieceMaterialEnumMap = {
  PieceMaterial.plastic: 'plastic',
  PieceMaterial.wood: 'wood',
  PieceMaterial.aluminum: 'aluminum',
};
