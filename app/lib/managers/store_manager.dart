import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/game_enums.dart';
import '../models/inventory.dart';
import '../models/store_item.dart';
import '../repositories/app_repositories.dart';
import 'auth_manager.dart';

/// 내가 산 상품과 고른 기물, 상점의 가격(`docs/monetization.md`). 로그인한 동안 보관함을 듣는다.
class StoreManager extends ChangeNotifier {
  final AuthManager authManager;

  StreamSubscription<Inventory?>? _subscription;

  // 지금 듣고 있는 사용자.
  String? _uid;
  Inventory? _inventory;

  // 지금 사용자의 보관함을 한 번이라도 읽었다. 문서가 없어도 읽은 것이다.
  var _inventoryRead = false;

  // 상품 ID별 기기 통화 가격 글자. 읽지 못했으면 비어 있다.
  Map<String, String> _prices = const {};

  StoreManager({required this.authManager}) {
    authManager.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    authManager.removeListener(_onAuthChanged);
    _subscription?.cancel();
    super.dispose();
  }

  /// 고른 기물. 산 기물만 쓴다.
  PieceMaterial get selectedMaterial {
    final inventory = _inventory;
    if (inventory == null || !inventory.materials.contains(inventory.selectedMaterial)) {
      return PieceMaterial.plastic;
    }
    return inventory.selectedMaterial;
  }

  /// 기보처럼 대국자의 기물을 알 수 없는 판에 쓸 기물. 양쪽 모두 내가 고른 기물이다.
  BoardMaterials get materials => (cho: selectedMaterial, han: selectedMaterial);

  bool get adsRemoved => _inventory?.adsRemoved ?? false;

  /// [adsRemoved]를 믿을 수 있다. 로그아웃했으면 산 것이 없고, 로그인했으면 보관함을 읽은 뒤다.
  bool get inventoryLoaded => _uid == null || _inventoryRead;

  bool isOwned(PieceMaterial material) {
    return material == PieceMaterial.plastic || (_inventory?.materials.contains(material) ?? false);
  }

  /// [item]의 기기 통화 가격 글자. 읽지 못했으면 null이다.
  String? getPrice(StoreItem item) => _prices[item.id];

  /// 스토어에서 가격을 읽는다. 실패하면 다음에 상점을 열 때 다시 읽는다.
  Future<void> loadPrices() async {
    try {
      final prices = await repositories.storePurchaseRepository.getPrices([
        for (final item in StoreItem.values) item.id,
      ]);
      _prices = prices;
      notifyListeners();
    } catch (error, stackTrace) {
      developer.log('StorePurchaseRepository.getPrices 실패', error: error, stackTrace: stackTrace);
    }
  }

  /// [item]을 산다. 결제가 끝나면 서버가 지급하고 지갑과 보관함을 듣는 쪽에 들어온다.
  Future<void> purchase(StoreItem item) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('로그인하지 않고 살 수 없습니다');
    }
    await repositories.storePurchaseRepository.purchase(uid, item.id);
  }

  Future<void> restorePurchases() async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('로그인하지 않고 복원할 수 없습니다');
    }
    await repositories.storePurchaseRepository.restore(uid);
  }

  /// 기물을 고른다. 보관함이 없으면 기본 기물만 있으므로 바꿀 것이 없다.
  Future<void> selectMaterial(PieceMaterial material) async {
    final uid = _uid;
    if (uid == null || _inventory == null) {
      return;
    }
    await repositories.inventoryRepository.updateSelectedMaterial(uid, material);
  }

  void _onAuthChanged() {
    final uid = authManager.uid;
    if (uid == _uid) {
      return;
    }
    _uid = uid;
    _subscription?.cancel();
    _subscription = null;
    _inventory = null;
    _inventoryRead = false;
    if (uid != null) {
      _subscription = repositories.inventoryRepository
          .watchInventory(uid)
          .listen(_onInventoryChanged, onError: _onWatchError);
    } else {
      _logOutOfStore();
    }
    notifyListeners();
  }

  void _onInventoryChanged(Inventory? inventory) {
    _inventory = inventory;
    _inventoryRead = true;
    notifyListeners();
  }

  void _onWatchError(Object error, StackTrace stackTrace) {
    developer.log('StoreManager 듣기 실패', error: error, stackTrace: stackTrace);
  }

  Future<void> _logOutOfStore() async {
    try {
      await repositories.storePurchaseRepository.logOut();
    } catch (error, stackTrace) {
      developer.log('StorePurchaseRepository.logOut 실패', error: error, stackTrace: stackTrace);
    }
  }
}
