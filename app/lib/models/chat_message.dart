import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

/// 채팅 종류(`docs/moderation.md`의 채팅 종류). Functions의 `ChatChannel`과 값을 일치시킨다.
enum ChatChannel {
  /// 대국실의 로비 채팅. 로그인한 사용자.
  lobby,

  /// 두 대국자.
  game,

  /// 대국을 관전하는 로그인 사용자. 대국자는 대국이 끝난 뒤에만 본다.
  spectator,
}

/// 채팅 Callable이 거절한 이유. 오류의 `details.code`로 받는다.
///
/// Functions의 `ChatErrorCode`(`server/functions/src/models/chat.ts`)와 값을 일치시킨다.
enum ChatErrorCode {
  profileRequired,
  sanctioned,
  chatRestricted,
  notFound,
  notAllowed,
  messageBlocked,
  moderationUnavailable,
  featureDisabled;

  /// 서버가 보낸 이름에 맞는 값. 모르는 값이면 null이다.
  static ChatErrorCode? fromName(Object? name) => values.asNameMap()[name];
}

/// RTDB `chats_lobby/{messageId}`, `chats_game/{gameId}/{messageId}`, `chats_spectator/{gameId}/{messageId}`.
///
/// Functions만 쓴다. 필드는 Functions의 `ChatMessage`(`server/functions/src/models/chat.ts`)와 일치시킨다.
@JsonSerializable(createToJson: false)
class ChatMessage {
  final String uid;

  /// 보낼 때의 닉네임.
  final String nickname;
  final String text;

  /// 서버가 받은 시각(ms).
  final int sentAt;

  const ChatMessage({required this.uid, required this.nickname, required this.text, required this.sentAt});

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
}

/// 채팅 메시지와 그 ID. ID는 RTDB push 키라 보낸 순서대로 정렬된다.
typedef ChatEntry = ({String id, ChatMessage message});
