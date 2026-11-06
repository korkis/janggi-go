import '../firebase/firestore_client.dart';
import '../models/coin.dart';

/// Firestore `coin_wallets/{uid}`. 앱은 본인 것을 읽기만 하고 Functions와 대국 서버가 쓴다.
class CoinWalletsRepository {
  final FirestoreClient firestore;

  const CoinWalletsRepository({required this.firestore});

  static const collection = 'coin_wallets';

  /// [uid]의 지갑. 엽전이 생기기 전에 가입했으면 null.
  Future<CoinWallet?> getWallet(String uid) async {
    final data = await firestore.getDocument('$collection/$uid');
    return data == null ? null : CoinWallet.fromJson(data);
  }

  Future<Map<String, CoinWallet?>> getWalletsInTransaction(FirestoreTransaction transaction, List<String> uids) async {
    final documents = await transaction.getAll([for (final uid in uids) '$collection/$uid']);
    return {
      for (final uid in uids)
        uid: switch (documents['$collection/$uid']) {
          final data? => CoinWallet.fromJson(data),
          null => null,
        },
    };
  }

  void setWalletInTransaction(FirestoreTransaction transaction, String uid, CoinWallet wallet) {
    transaction.set('$collection/$uid', wallet.toJson());
  }
}
