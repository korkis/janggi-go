import '../config.dart';
import '../firebase/firestore_client.dart';
import '../models/quick_queue_entry.dart';

/// Firestore `quick_queue/{uid}`. 빠른 대국 대기열이다. 서버 전용이다.
class QuickQueueRepository {
  final FirestoreClient firestore;

  const QuickQueueRepository({required this.firestore});

  static const collection = 'quick_queue';

  /// [uid]의 대기열 항목. 대기열에 없으면 null.
  Future<QuickQueueEntry?> getEntry(String uid) async {
    final data = await firestore.getDocument('$collection/$uid');
    return data == null ? null : QuickQueueEntry.fromJson(data);
  }

  /// [rating]에 가까운 대기열 항목. 위쪽(같은 값 포함)과 아래쪽에서 가까운 순서로 [quickMatchCandidateLimit]개씩 읽는다.
  /// 결과는 uid별 항목이며 순서는 정하지 않는다. 부른 사람의 항목도 들어 있을 수 있다.
  Future<Map<String, QuickQueueEntry>> getEntriesNear(double rating) async {
    final (above, below) = await (
      firestore.runQuery(
        collection,
        filters: [QueryFilter('rating', QueryOperator.greaterThanOrEqual, rating)],
        orderBy: [const QueryOrder('rating')],
        limit: quickMatchCandidateLimit,
      ),
      firestore.runQuery(
        collection,
        filters: [QueryFilter('rating', QueryOperator.lessThan, rating)],
        orderBy: [const QueryOrder('rating', descending: true)],
        limit: quickMatchCandidateLimit,
      ),
    ).wait;
    return {
      for (final document in [...above, ...below]) document.id: QuickQueueEntry.fromJson(document.data),
    };
  }

  Future<Map<String, QuickQueueEntry?>> getEntriesInTransaction(
    FirestoreTransaction transaction,
    List<String> uids,
  ) async {
    final documents = await transaction.getAll([for (final uid in uids) '$collection/$uid']);
    return {
      for (final uid in uids)
        uid: switch (documents['$collection/$uid']) {
          final data? => QuickQueueEntry.fromJson(data),
          null => null,
        },
    };
  }

  void setEntryInTransaction(FirestoreTransaction transaction, String uid, QuickQueueEntry entry) {
    transaction.set('$collection/$uid', entry.toJson());
  }

  void deleteEntryInTransaction(FirestoreTransaction transaction, String uid) {
    transaction.delete('$collection/$uid');
  }
}
