import 'dart:math';

import '../firebase/firestore_client.dart';
import '../models/challenge.dart';
import '../models/game_enums.dart';

/// Firestore `challenges/{challengeId}`. 대국 신청이다. 대국 서버만 쓴다.
class ChallengesRepository {
  final FirestoreClient firestore;
  final Random _random;

  ChallengesRepository({required this.firestore, Random? random}) : _random = random ?? Random.secure();

  static const collection = 'challenges';

  static const _idCharacters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static const _idLength = 20;

  /// 추측할 수 없는 20자 신청 ID.
  String createChallengeId() =>
      List.generate(_idLength, (_) => _idCharacters[_random.nextInt(_idCharacters.length)]).join();

  /// 신청. 없으면 null.
  Future<Challenge?> getChallenge(String challengeId) async {
    final data = await firestore.getDocument('$collection/$challengeId');
    return data == null ? null : Challenge.fromJson(data);
  }

  Future<Challenge?> getChallengeInTransaction(FirestoreTransaction transaction, String challengeId) async {
    final data = await transaction.get('$collection/$challengeId');
    return data == null ? null : Challenge.fromJson(data);
  }

  /// 새 신청을 만든다. 같은 ID가 있으면 커밋이 실패한다.
  void createChallengeInTransaction(FirestoreTransaction transaction, String challengeId, Challenge challenge) {
    transaction.create('$collection/$challengeId', challenge.toJson());
  }

  /// 신청 상태를 바꾼다. [gameId]를 주면 수락해서 만든 대국도 쓴다.
  void updateStatusInTransaction(
    FirestoreTransaction transaction,
    String challengeId, {
    required ChallengeStatus status,
    String? gameId,
    required DateTime now,
  }) {
    transaction.update('$collection/$challengeId', {'status': status.name, 'gameId': ?gameId, 'updatedAt': now});
  }
}
