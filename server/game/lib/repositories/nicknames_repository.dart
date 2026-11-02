import '../firebase/firestore_client.dart';

/// Firestore `nicknames/{nicknameKey}`. 닉네임 중복을 막는 예약 문서다. Functions가 쓰고 대국 서버는 읽기만 한다.
class NicknamesRepository {
  final FirestoreClient firestore;

  const NicknamesRepository({required this.firestore});

  static const collection = 'nicknames';

  /// [nickname]을 쓰는 사용자의 uid. 없으면 null.
  ///
  /// 문서 ID는 영문을 소문자로 바꾼 닉네임이다. Functions의 `getNicknameKey`(`server/functions/src/services/nicknameService.ts`)와 같다.
  Future<String?> getUidByNickname(String nickname) async {
    final data = await firestore.getDocument('$collection/${nickname.toLowerCase()}');
    return data?['uid'] as String?;
  }
}
