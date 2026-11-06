import '../firebase/firestore_client.dart';
import '../models/game_enums.dart';
import '../models/inventory.dart';

/// Firestore `inventories/{uid}`. 지급과 환불은 Functions가 하고 고르기는 앱이 한다. 대국 서버는 읽기만 한다.
class InventoriesRepository {
  final FirestoreClient firestore;

  const InventoriesRepository({required this.firestore});

  static const collection = 'inventories';

  /// [uid]가 대국에서 쓸 기물. 산 것이 없거나 고른 기물을 갖고 있지 않으면(환불과 엇갈린 경우) 기본 기물이다.
  Future<PieceMaterial> getGameMaterial(String uid) async {
    final data = await firestore.getDocument('$collection/$uid');
    if (data == null) {
      return PieceMaterial.plastic;
    }
    final inventory = Inventory.fromJson(data);
    return inventory.materials.contains(inventory.selectedMaterial)
        ? inventory.selectedMaterial
        : PieceMaterial.plastic;
  }
}
