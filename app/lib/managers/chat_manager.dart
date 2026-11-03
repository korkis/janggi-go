import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../repositories/app_repositories.dart';
import 'auth_manager.dart';
import 'block_manager.dart';

/// 채팅 창에 보여줄 한 줄. 메시지이거나 보내지 못한 메시지의 안내다.
sealed class ChatItem {
  const ChatItem();
}

class ChatMessageItem extends ChatItem {
  final ChatEntry entry;

  /// 내가 보낸 메시지.
  final bool mine;

  const ChatMessageItem({required this.entry, required this.mine});
}

/// 검사에 걸리는 등 보내지 못한 메시지의 안내. 가운데 회색으로 보여준다(`docs/screens.md`의 채팅).
class ChatNoticeItem extends ChatItem {
  final String text;

  const ChatNoticeItem({required this.text});
}

/// 채팅 하나(로비, 대국, 관전)의 메시지와 보내기·신고. 채팅을 보여주는 화면이 만들고 `dispose()`한다.
///
/// 로그인한 동안 최근 메시지를 듣는다. 로그인하지 않은 관전자는 채팅을 읽지 못하므로 듣지 않고, 로그인하면 바로 듣는다.
/// 내가 차단한 사람의 메시지와, 대국 채팅에서 상대 채팅을 끄면 상대 메시지를 숨긴다.
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

  // 보내지 못한 메시지의 안내와, 그때 마지막이던 메시지 ID. 그 메시지 뒤에 보여준다. 메시지가 없었으면 null이다.
  final _notices = <({String? afterId, String text})>[];

  // 이 메시지까지는 읽었다. 이 뒤의 다른 사람 메시지 수가 새 메시지 수다.
  String? _lastReadId;

  // 채팅 창이 열려 있다. 열려 있는 동안 들어온 메시지는 바로 읽은 것으로 본다.
  var _open = false;

  var _sending = false;
  var _opponentMuted = false;

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

  bool get sending => _sending;

  /// 대국 채팅에서 상대 채팅을 껐다.
  bool get opponentMuted => _opponentMuted;

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
      for (final notice in _notices)
        if (notice.afterId == null) ChatNoticeItem(text: notice.text),
    ];
    for (final entry in _entries) {
      if (_isVisible(entry)) {
        items.add(ChatMessageItem(entry: entry, mine: _isMine(entry)));
      }
      for (final notice in _notices) {
        if (notice.afterId == entry.id) {
          items.add(ChatNoticeItem(text: notice.text));
        }
      }
    }
    // 안내를 단 메시지가 100개 밖으로 밀려났으면 맨 뒤에 둔다.
    for (final notice in _notices) {
      final afterId = notice.afterId;
      if (afterId != null && !visibleIds.contains(afterId)) {
        items.add(ChatNoticeItem(text: notice.text));
      }
    }
    return items;
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

  /// [text]를 보낸다. 서버가 검사해 통과하면 메시지가 채팅에 들어온다. 검사에 걸리면 그 이유의 AppException을 던진다.
  Future<void> send(String text) async {
    try {
      _sending = true;
      notifyListeners();
      await repositories.chatRepository.sendChatMessage(channel, gameId, text);
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// 다른 사람의 메시지를 신고한다.
  Future<void> report(String messageId) => repositories.chatRepository.reportMessage(channel, gameId, messageId);

  /// 보내지 못한 메시지의 안내를 지금 마지막 메시지 뒤에 보여준다.
  void addNotice(String text) {
    _notices.add((afterId: _entries.isEmpty ? null : _entries.last.id, text: text));
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
