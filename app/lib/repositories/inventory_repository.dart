import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_enums.dart';
import '../models/inventory.dart';

/// Firestore `inventories` 컬렉션. 본인만 읽는다. 지급과 환불은 서버가 하고 앱은 고른 기물만 바꾼다.
class InventoryRepository {
  final FirebaseFirestore firestore;

  InventoryRepository({required this.firestore});

  /// 내 보관함을 듣는다. 산 적이 없으면 null을 보낸다.
  Stream<Inventory?> watchInventory(String uid) =>
      firestore.collection('inventories').doc(uid).snapshots().map(_decode);

  /// 고른 기물을 바꾼다. 보안 규칙이 기본 기물이나 산 기물만 허용한다.
  Future<void> updateSelectedMaterial(String uid, PieceMaterial material) async {
    await firestore.collection('inventories').doc(uid).update({'selectedMaterial': material.name});
  }

  static Inventory? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return data == null ? null : Inventory.fromJson(data);
  }
}
