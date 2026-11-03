import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

/// RTDB `spectators/{gameId}/{viewerId}`. 관전자 수를 세는 표시다(`docs/server.md`의 관전자 수).
///
/// 로그인하지 않아도 쓴다. 앱은 만들고 지우기만 하고, 세기는 대국 서버가 한다.
class SpectatorRepository {
  final FirebaseDatabase database;
  final Random _random;

  SpectatorRepository({required this.database, Random? random}) : _random = random ?? Random.secure();

  static const _path = 'spectators';

  static const _idCharacters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static const _idLength = 20;

  /// 관전 화면을 열 때마다 새로 만드는 20자 임의 문자열. 보안 규칙이 길이를 확인한다.
  String createViewerId() =>
      List.generate(_idLength, (_) => _idCharacters[_random.nextInt(_idCharacters.length)]).join();

  /// 연결이 끊기면 지우도록 먼저 걸어 두고 표시를 서버 시각으로 만든다.
  Future<void> createSpectator(String gameId, String viewerId) async {
    final ref = database.ref('$_path/$gameId/$viewerId');
    await ref.onDisconnect().remove();
    await ref.set(ServerValue.timestamp);
  }

  /// 관전 화면을 닫을 때 표시를 지우고 걸어 둔 `onDisconnect`도 거둔다.
  Future<void> removeSpectator(String gameId, String viewerId) async {
    final ref = database.ref('$_path/$gameId/$viewerId');
    await ref.remove();
    await ref.onDisconnect().cancel();
  }
}
