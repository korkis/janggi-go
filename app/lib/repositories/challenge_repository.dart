import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:janggi_core/janggi_core.dart';

import '../models/challenge.dart';
import '../models/game_enums.dart';
import 'game_server_call.dart';

/// Firestore `challenges` 컬렉션과 대국 서버의 신청 API. 신청은 대국 서버만 쓰고 앱은 보낸 사람과 받는 사람만 읽는다.
class ChallengeRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  /// 대국 서버 주소를 돌려준다. 운영 주소가 없는 빌드에서도 앱이 켜지도록 부를 때 구한다.
  final Uri Function() getServerUrl;

  ChallengeRepository({required this.firestore, required this.functions, required this.getServerUrl});

  /// 신청을 듣는다. 없으면 null을 보낸다.
  Stream<Challenge?> watchChallenge(String challengeId) =>
      firestore.collection('challenges').doc(challengeId).snapshots().map(_decode);

  /// [toUid]에게 대국을 신청하고 신청 ID를 돌려준다. 접장기면 [handicapRemover]와 [handicapPieces]를, 아니면 [senderSide]를 준다.
  Future<String> sendChallenge({
    required String toUid,
    required SideChoice? senderSide,
    required HandicapRemover? handicapRemover,
    required List<HandicapPiece>? handicapPieces,
  }) async {
    final result = await _call('sendChallenge', {
      'toUid': toUid,
      if (senderSide != null) 'senderSide': senderSide.name,
      if (handicapRemover != null && handicapPieces != null)
        'handicap': {
          'remover': handicapRemover.name,
          'pieces': [for (final piece in handicapPieces) piece.name],
        },
    });
    return result['challengeId'] as String;
  }

  /// 방장이 [toUid]를 방 [roomId]에 초대한다. 조건은 방 조건을 쓴다. 신청 ID를 돌려준다.
  Future<String> sendRoomInvite({required String toUid, required String roomId}) async {
    final result = await _call('sendChallenge', {'toUid': toUid, 'roomId': roomId});
    return result['challengeId'] as String;
  }

  /// 보낸 신청을 취소한다.
  Future<void> cancelChallenge(String challengeId) async {
    await _call('cancelChallenge', {'challengeId': challengeId});
  }

  /// 받은 신청을 수락하거나 거절한다. 수락하면 만든 대국 또는 들어간 방(방 초대)을 돌려준다.
  Future<({String? gameId, String? roomId})> respondChallenge(String challengeId, {required bool accepted}) async {
    final result = await _call('respondChallenge', {'challengeId': challengeId, 'accepted': accepted});
    return (gameId: result['gameId'] as String?, roomId: result['roomId'] as String?);
  }

  Future<Map<String, Object?>> _call(String name, Map<String, Object?>? data) =>
      callGameServer(functions, getServerUrl(), name, data);

  static Challenge? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return data == null ? null : Challenge.fromJson(data);
  }
}
