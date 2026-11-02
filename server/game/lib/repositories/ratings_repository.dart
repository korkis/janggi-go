import '../firebase/firestore_client.dart';
import '../models/rating.dart';

/// Firestore `ratings/{uid}`. 서버 전용 레이팅이다.
class RatingsRepository {
  final FirestoreClient firestore;

  const RatingsRepository({required this.firestore});

  static const collection = 'ratings';

  /// [uid]의 레이팅. 급수 대국을 두지 않았으면 null.
  Future<Rating?> getRating(String uid) async {
    final data = await firestore.getDocument('$collection/$uid');
    return data == null ? null : Rating.fromJson(data);
  }

  Future<Map<String, Rating?>> getRatingsInTransaction(FirestoreTransaction transaction, List<String> uids) async {
    final documents = await transaction.getAll([for (final uid in uids) '$collection/$uid']);
    return {
      for (final uid in uids)
        uid: switch (documents['$collection/$uid']) {
          final data? => Rating.fromJson(data),
          null => null,
        },
    };
  }

  void setRatingInTransaction(FirestoreTransaction transaction, String uid, Rating rating) {
    transaction.set('$collection/$uid', rating.toJson());
  }
}
