// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Inventory _$InventoryFromJson(Map<String, dynamic> json) => Inventory(
  materials: (json['materials'] as List<dynamic>)
      .map((e) => $enumDecode(_$PieceMaterialEnumMap, e, unknownValue: PieceMaterial.plastic))
      .toList(),
  selectedMaterial: $enumDecode(_$PieceMaterialEnumMap, json['selectedMaterial'], unknownValue: PieceMaterial.plastic),
  adsRemoved: json['adsRemoved'] as bool,
);

const _$PieceMaterialEnumMap = {
  PieceMaterial.plastic: 'plastic',
  PieceMaterial.wood: 'wood',
  PieceMaterial.aluminum: 'aluminum',
};
