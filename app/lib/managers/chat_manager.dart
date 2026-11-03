import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../repositories/app_repositories.dart';
import 'auth_manager.dart';
import 'block_manager.dart';

/// 채팅 창에 보여줄 한 줄. 메시지, 보내는 내 메시지, 신고·차단 결과 안내 가운데 하나다.
sealed class ChatItem {
  const ChatItem();
}

class ChatMessageItem extends ChatItem {
  final ChatEntry entry;

  /// 내가 보낸 메시지.
  final bool mine;

  const ChatMessageItem({required this.entry, required this.mine});
}

/// 내가 보낸 뒤 서버에 아직 저장되지 않은 메시지. 보내기를 누르는 즉시 보낸 것처럼 보여준다(`docs/screens.md`의 채팅).
class ChatOutgoingItem extends ChatItem {
  final String text;

  /// 보내지 못한 이유(검사에 걸림, 네트워크 문제 등). 보낸 것처럼 보이는 동안은 null이다.
  final Object? error;

  const ChatOutgoingItem({required this.text, this.error});
}

/// 신고·차단 결과 같은 안내. 가운데 회색으로 보여준다.
class ChatNoticeItem extends ChatItem {
  final String text;

  const ChatNoticeItem({required this.text});
}

/// 채팅 하나(로비, 대국, 관전)의 메시지와 보내기·신고. 채팅을 보여주는 화면이 만들고 `dispose()`한다.
///
/// 로그인한 동안 최근 메시지를 듣는다. 로그인하지 않은 관전자는 채팅을 읽지 못하므로 듣지 않고, 로그인하면 바로 듣는다.
/// 내가 차단한 사람의 메시지와, 대국 채팅에서 상대 채팅을 끄면 상대 메시지를 숨긴다.
///
/// 내 메시지는 보내자마자 [ChatOutgoingItem]으로 보여주고, 서버가 저장한 같은 메시지가 들어오면 그 메시지로 바꾼다. 서버가
/// 거절하거나 보내지 못하면 그 말풍선을 보내지 못한 것으로 바꾼다.
class ChatManager extends ChangeNotifier {
  final ChatChannel channel;

  /// 대국·관전 채팅의 대국. 로비 채팅이면 null이다.
  final String? gameId;

  final AuthManager authManager;
  final BlockManager blockManager;

  StreamSubscription<List<ChatEntry>>? _subscription;

  // 지금 듣고 있는 사용자.
  String? _uid;
  List<ChatEntry> _entries = const [];
  var _loaded = false;

  // 서버 메시지 사이에 끼워 보여줄 보내는 내 메시지와 안내. 그때 마지막이던 메시지 ID 뒤에 보여준다. 메시지가 없었으면 null이다.
  final _extras = <({String? afterId, ChatItem item})>[];

  // 보내는 내 메시지와 짝지은 서버 메시지 ID. 같은 말을 여러 번 보내도 한 메시지를 두 번 짝짓지 않는다.
  final _matchedIds = <String>{};

  // 이 메시지까지는 읽었다. 이 뒤의 다른 사람 메시지 수가 새 메시지 수다.
  String? _lastReadId;

  // 채팅 창이 열려 있다. 열려 있는 동안 들어온 메시지는 바로 읽은 것으로 본다.
  var _open = false;

  var _opponentMuted = false;

  // 대국이 끝난 뒤 대국 화면을 나간 상대의 닉네임. 나갔으면 입력을 막는다.
  String? _leftNickname;

  ChatManager({required this.channel, this.gameId, required this.authManager, required this.blockManager}) {
    authManager.addListener(_onAuthChanged);
    blockManager.addListener(notifyListeners);
    _onAuthChanged();
  }

  @override
  void dispose() {
    authManager.removeListener(_onAuthChanged);
    blockManager.removeListener(notifyListeners);
    _subscription?.cancel();
    super.dispose();
  }

  /// 로그인해서 채팅을 읽고 쓸 수 있다.
  bool get signedIn => _uid != null;

  /// 처음 메시지를 받았다.
  bool get loaded => _loaded;

  /// 대국 채팅에서 상대 채팅을 껐다.
  bool get opponentMuted => _opponentMuted;

  /// 대국이 끝난 뒤 대국 화면을 나간 상대의 닉네임. 나가지 않았으면 null이다. 나갔으면 더 보낼 수 없다.
  String? get leftNickname => _leftNickname;

  /// 창이 닫혀 있는 동안 들어온 다른 사람의 메시지 수. 숨긴 메시지는 세지 않는다.
  int get unreadCount {
    final lastReadId = _lastReadId;
    var count = 0;
    for (final entry in _entries) {
      if (_isVisible(entry) && !_isMine(entry) && (lastReadId == null || entry.id.compareTo(lastReadId) > 0)) {
        count++;
      }
    }
    return count;
  }

  /// 보여줄 메시지와 안내를 오래된 순서로.
  List<ChatItem> get items {
    final visibleIds = {for (final entry in _entries) entry.id};
    final items = <ChatItem>[
      for (final extra in _extras)
        if (extra.afterId == null) extra.item,
    ];
    for (final entry in _entries) {
      if (_isVisible(entry)) {
        items.add(ChatMessageItem(entry: entry, mine: _isMine(entry)));
      }
      for (final extra in _extras) {
        if (extra.afterId == entry.id) {
          items.add(extra.item);
        }
      }
    }
    // 앞에 둔 메시지가 100개 밖으로 밀려났으면 맨 뒤에 둔다.
    for (final extra in _extras) {
      final afterId = extra.afterId;
      if (afterId != null && !visibleIds.contains(afterId)) {
        items.add(extra.item);
      }
    }
    return items;
  }

  /// 마지막 메시지(보내는 내 메시지 포함). 대국 화면의 채팅 미리보기에 쓴다. 메시지가 없으면 null이다.
  ChatItem? get lastMessage {
    final all = items;
    for (var i = all.length - 1; i >= 0; i--) {
      final item = all[i];
      if (item is ChatMessageItem || item is ChatOutgoingItem) {
        return item;
      }
    }
    return null;
  }

  /// 채팅 창을 열고 닫을 때 부른다. 열면 지금까지의 메시지를 읽은 것으로 본다.
  void setOpen(bool open) {
    _open = open;
    if (!open) {
      return;
    }
    final hadUnread = unreadCount > 0;
    _markRead();
    if (hadUnread) {
      notifyListeners();
    }
  }

  /// 대국 채팅의 상대 채팅 끄기를 바꾼다.
  void toggleOpponentMuted() {
    _opponentMuted = !_opponentMuted;
    notifyListeners();
  }

  /// 대국이 끝난 뒤 상대([nickname])가 대국 화면을 나갔다. 이 채팅에 더 보낼 수 없다. 상대 앱이 다시 앞으로 오면 null로 되돌린다.
  void setLeft(String? nickname) {
    if (_leftNickname == nickname) {
      return;
    }
    _leftNickname = nickname;
    notifyListeners();
  }

  /// [text]를 보낸다. 보내기 전에 내 화면에 먼저 보여준다. 서버가 검사해 통과하면 메시지가 채팅에 들어온다.
  /// 검사에 걸리거나 보내지 못하면 그 말풍선을 보내지 못한 것으로 바꾸고 오류를 던진다. 검사에 걸리면 그 이유의 AppException이다.
  Future<void> send(String text) async {
    final pending = ChatOutgoingItem(text: text);
    _extras.add((afterId: _entries.isEmpty ? null : _entries.last.id, item: pending));
    notifyListeners();
    try {
      await repositories.chatRepository.sendChatMessage(channel, gameId, text);
      _matchOutgoing();
    } catch (error) {
      _replaceExtra(pending, ChatOutgoingItem(text: text, error: error));
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// 다른 사람의 메시지를 신고한다.
  Future<void> report(String messageId) => repositories.chatRepository.reportMessage(channel, gameId, messageId);

  /// 신고·차단 결과 같은 안내를 지금 마지막 메시지 뒤에 보여준다.
  void addNotice(String text) {
    _extras.add((afterId: _entries.isEmpty ? null : _entries.last.id, item: ChatNoticeItem(text: text)));
    notifyListeners();
  }

  bool _isMine(ChatEntry entry) => entry.message.uid == _uid;

  bool _isVisible(ChatEntry entry) {
    final uid = entry.message.uid;
    if (uid == _uid) {
      return true;
    }
    if (blockManager.isBlocked(uid)) {
      return false;
    }
    return !(_opponentMuted && channel == ChatChannel.game);
  }

  void _replaceExtra(ChatItem from, ChatItem to) {
    final index = _extras.indexWhere((extra) => identical(extra.item, from));
    if (index >= 0) {
      _extras[index] = (afterId: _extras[index].afterId, item: to);
    }
  }

  /// 보내는 내 메시지마다 보낸 뒤에 들어온 같은 글자의 내 서버 메시지를 찾아, 있으면 보내는 메시지를 지운다. 서버 메시지와
  /// 보내기 결과는 어느 쪽이 먼저 올지 모르므로 둘 다 받을 때 맞춰 본다.
  void _matchOutgoing() {
    _extras.removeWhere(_isDelivered);
  }

  bool _isDelivered(({String? afterId, ChatItem item}) extra) {
    final item = extra.item;
    if (item is! ChatOutgoingItem || item.error != null) {
      return false;
    }
    final afterId = extra.afterId;
    for (final entry in _entries) {
      final after = afterId == null || entry.id.compareTo(afterId) > 0;
      if (after && _isMine(entry) && entry.message.text == item.text && !_matchedIds.contains(entry.id)) {
        _matchedIds.add(entry.id);
        return true;
      }
    }
    return false;
  }

  void _markRead() {
    if (_entries.isNotEmpty) {
      _lastReadId = _entries.last.id;
    }
  }

  void _onAuthChanged() {
    final uid = authManager.uid;
    if (uid == _uid) {
      return;
    }
    _uid = uid;
    _subscription?.cancel();
    _subscription = null;
    _entries = const [];
    _extras.clear();
    _matchedIds.clear();
    _loaded = false;
    _lastReadId = null;
    if (uid != null) {
      _subscription = repositories.chatRepository
          .watchMessages(channel, gameId)
          .listen(_onMessagesChanged, onError: _onMessagesError);
    }
    notifyListeners();
  }

  void _onMessagesChanged(List<ChatEntry> entries) {
    _entries = entries;
    _matchOutgoing();
    // 창을 열기 전의 지난 메시지는 새 메시지로 세지 않는다.
    if (!_loaded || _open) {
      _markRead();
    }
    _loaded = true;
    notifyListeners();
  }

  void _onMessagesError(Object error, StackTrace stackTrace) {
    developer.log('ChatManager $channel 채팅 듣기 실패', error: error, stackTrace: stackTrace);
    _loaded = true;
    notifyListeners();
  }
}
