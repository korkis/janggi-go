import 'game_enums.dart';

/// 상점에서 파는 상품(`docs/monetization.md`의 상품, 현금 충전).
///
/// [id]는 스토어와 RevenueCat의 상품 ID이고 Functions의 `STORE_PRODUCTS`(`server/functions/src/config.ts`)와 같다.
/// [priceWon]은 웹과, 스토어 가격을 읽지 못했을 때 보여주는 값이다. 앱은 스토어가 알려 준 기기의 통화 가격을 보여준다.
enum StoreItem {
  coins300('coins_300', priceWon: 1200, coins: 300),
  coins1100('coins_1100', priceWon: 3900, coins: 1100),
  coins3000('coins_3000', priceWon: 9900, coins: 3000),
  piecesWood('pieces_wood', priceWon: 4900, material: PieceMaterial.wood),
  piecesAluminum('pieces_aluminum', priceWon: 4900, material: PieceMaterial.aluminum),
  removeAds('remove_ads', priceWon: 4900);

  static const coinItems = [coins300, coins1100, coins3000];

  final String id;
  final int priceWon;

  /// 충전 상품이 주는 엽전.
  final int? coins;

  /// 기물 상품의 재질.
  final PieceMaterial? material;

  const StoreItem(this.id, {required this.priceWon, this.coins, this.material});
}
