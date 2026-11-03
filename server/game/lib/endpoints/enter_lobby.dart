import '../http/callable.dart';
import '../services/lobby_service.dart';

/// 대국실 접속자 목록에 들어간다(`docs/server.md`의 접속자 목록). 파라미터와 결과는 없다.
class EnterLobbyEndpoint extends CallableEndpoint {
  final LobbyService lobbyService;

  EnterLobbyEndpoint({required this.lobbyService});

  @override
  String get name => 'enterLobby';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    await lobbyService.enterLobby(request.uid, request.user, now: request.receivedAt);
    return null;
  }
}
