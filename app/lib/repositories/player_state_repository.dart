import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/player_state.dart';

/// Firestore `player_states` 컬렉션. 대국 서버만 쓰고 앱은 본인 문서를 듣기만 한다.
class PlayerStateRepository {
  final FirebaseFirestore firestore;

  PlayerStateRepository({required this.firestore});

  /// 본인의 상태를 듣는다. 아직 아무것도 하지 않아 문서가 없으면 null을 보낸다.
  Stream<PlayerState?> watchPlayerState(String uid) =>
      firestore.collection('player_states').doc(uid).snapshots().map(_decode);

  static PlayerState? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return data == null ? null : PlayerState.fromJson(data);
  }
}
