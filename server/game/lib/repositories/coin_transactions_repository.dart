import '../firebase/firestore_client.dart';
import '../models/coin.dart';

/// Firestore `coin_transactions/{transactionId}`. 서버 전용 엽전 내역이다.
class CoinTransactionsRepository {
  final FirestoreClient firestore;

  const CoinTransactionsRepository({required this.firestore});

  static const collection = 'coin_transactions';

  /// [transactionIds] 각각의 내역. 없으면 null.
  Future<Map<String, CoinTransaction?>> getTransactionsInTransaction(
    FirestoreTransaction transaction,
    List<String> transactionIds,
  ) async {
    final documents = await transaction.getAll([for (final id in transactionIds) '$collection/$id']);
    return {
      for (final id in transactionIds)
        id: switch (documents['$collection/$id']) {
          final data? => CoinTransaction.fromJson(data),
          null => null,
        },
    };
  }

  /// [transactionId] 내역. 없으면 null.
  Future<CoinTransaction?> getTransaction(String transactionId) async {
    final data = await firestore.getDocument('$collection/$transactionId');
    return data == null ? null : CoinTransaction.fromJson(data);
  }

  /// 내역을 만든다. 같은 ID가 이미 있으면 커밋이 실패해 지갑도 바뀌지 않는다.
  void createTransactionInTransaction(
    FirestoreTransaction transaction,
    String transactionId,
    CoinTransaction coinTransaction,
  ) {
    transaction.create('$collection/$transactionId', coinTransaction.toJson());
  }
}
