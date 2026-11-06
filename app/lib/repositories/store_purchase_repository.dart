import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../utils/app_exception.dart';

/// 스토어 결제(RevenueCat). 돈만 받고 끝난다. 산 것은 RevenueCat 웹훅을 받은 서버가 주므로(`docs/server.md`의 앱 결제) 앱은 지갑과 보관함을
/// 듣고 있으면 된다.
class StorePurchaseRepository {
  /// RevenueCat 공개 API 키. 웹과 에뮬레이터 빌드처럼 팔지 않는 곳이면 null이다.
  final String? apiKey;

  var _configured = false;

  // RevenueCat에 로그인한 사용자.
  String? _loggedInUid;

  // 스토어에서 읽어 둔 상품. 결제를 시작할 때 쓴다.
  final _products = <String, StoreProduct>{};

  StorePurchaseRepository({required this.apiKey});

  /// [productIds]의 기기 통화 가격 글자(₩4,900 등). 스토어에 없는 상품은 빠진다. 팔지 않는 곳이면 비어 있다.
  Future<Map<String, String>> getPrices(List<String> productIds) async {
    if (!await _configure()) {
      return const {};
    }
    final products = await Purchases.getProducts(productIds, productCategory: ProductCategory.nonSubscription);
    for (final product in products) {
      _products[product.identifier] = product;
    }
    return {for (final product in products) product.identifier: product.priceString};
  }

  /// [uid]로 [productId]를 산다. 산 사람을 알 수 있도록 결제 전에 언제나 RevenueCat에 로그인한다.
  Future<void> purchase(String uid, String productId) async {
    if (!await _configure()) {
      throw const AppException(AppErrorCode.storeUnavailable);
    }
    try {
      await _logIn(uid);
      final product = _products[productId] ?? (await _fetchProduct(productId));
      await Purchases.purchase(PurchaseParams.storeProduct(product));
    } on PlatformException catch (error) {
      throw _toAppException(error) ?? error;
    }
  }

  /// [uid]의 구매를 스토어에서 다시 읽어 RevenueCat에 알린다. 서버가 아직 모르는 구매가 있으면 웹훅으로 지급된다.
  Future<void> restore(String uid) async {
    if (!await _configure()) {
      throw const AppException(AppErrorCode.storeUnavailable);
    }
    await _logIn(uid);
    await Purchases.restorePurchases();
  }

  /// 앱에서 로그아웃하면 RevenueCat에서도 로그아웃해 다음 사람의 구매에 섞이지 않게 한다.
  Future<void> logOut() async {
    if (_loggedInUid == null) {
      return;
    }
    await Purchases.logOut();
    _loggedInUid = null;
  }

  Future<bool> _configure() async {
    final key = apiKey;
    if (key == null) {
      return false;
    }
    if (!_configured) {
      await Purchases.configure(PurchasesConfiguration(key));
      _configured = true;
    }
    return true;
  }

  Future<void> _logIn(String uid) async {
    if (_loggedInUid == uid) {
      return;
    }
    await Purchases.logIn(uid);
    _loggedInUid = uid;
  }

  Future<StoreProduct> _fetchProduct(String productId) async {
    await getPrices([productId]);
    final product = _products[productId];
    if (product == null) {
      throw const AppException(AppErrorCode.storeUnavailable);
    }
    return product;
  }

  static AppException? _toAppException(PlatformException error) {
    return switch (PurchasesErrorHelper.getErrorCode(error)) {
      PurchasesErrorCode.purchaseCancelledError => const AppException(AppErrorCode.purchaseCanceled),
      PurchasesErrorCode.paymentPendingError => const AppException(AppErrorCode.purchasePending),
      PurchasesErrorCode.productAlreadyPurchasedError => const AppException(AppErrorCode.purchaseAlreadyOwned),
      _ => null,
    };
  }
}
