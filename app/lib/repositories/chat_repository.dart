import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/chat_message.dart';
import '../utils/app_exception.dart';
import 'game_repository.dart';

/// RTDB `chats_lobby`, `chats_game`, `chats_spectator`와 채팅 Callable(`sendChatMessage`, `reportMessage`).
///
/// 세 경로는 같은 메시지 모양의 변형이라 한 repository가 채팅 종류로 경로를 고른다. 메시지는 Functions만 쓰고, 앱은 경로별 보안 규칙
/// 안에서 읽기만 한다(`docs/database.md`).
class ChatRepository {
  final FirebaseDatabase database;
  final FirebaseFunctions functions;

  ChatRepository({required this.database, required this.functions});

  /// 채팅 창에 보여주는 최근 메시지 수.
  static const _messageLimit = 100;

  static String _getPath(ChatChannel channel, String? gameId) {
    final path = switch (channel) {
      ChatChannel.lobby => 'chats_lobby',
      ChatChannel.game => 'chats_game',
      ChatChannel.spectator => 'chats_spectator',
    };
    return gameId == null ? path : '$path/$gameId';
  }

  /// 최근 메시지를 보낸 순서대로 듣는다. 로비 채팅은 [gameId]가 null이다.
  Stream<List<ChatEntry>> watchMessages(ChatChannel channel, String? gameId) =>
      database.ref(_getPath(channel, gameId)).orderByKey().limitToLast(_messageLimit).onValue.map(_decode);

  /// 메시지를 보낸다. 서버가 검사해 통과하면 저장한다. 검사에 걸리거나 채팅이 제한되었으면 그 이유의 AppException을 던진다.
  Future<void> sendChatMessage(ChatChannel channel, String? gameId, String text) async {
    await _call('sendChatMessage', {'channel': channel.name, 'gameId': ?gameId, 'text': text});
  }

  /// 다른 사람의 메시지를 신고한다. 서버가 앞뒤 메시지와 검사 결과를 함께 저장한다.
  Future<void> reportMessage(ChatChannel channel, String? gameId, String messageId) async {
    await _call('reportMessage', {'channel': channel.name, 'gameId': ?gameId, 'messageId': messageId});
  }

  Future<void> _call(String name, Map<String, Object?> data) async {
    try {
      await functions.httpsCallable(name).call<Object?>(data);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final code = details is Map ? ChatErrorCode.fromName(details['code']) : null;
      final appException = code == null ? null : AppException.fromChatErrorCode(code);
      if (appException == null) {
        rethrow;
      }
      throw appException;
    }
  }

  static List<ChatEntry> _decode(DatabaseEvent event) {
    return [
      for (final child in event.snapshot.children)
        (id: child.key!, message: ChatMessage.fromJson(convertDatabaseValue(child.value) as Map<String, dynamic>)),
    ];
  }
}
