import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../managers/chat_manager.dart';
import '../models/chat_message.dart';
import '../repositories/app_repositories.dart';
import '../screens/login_flow.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import 'adaptive_layout.dart';
import 'game_scaffold.dart';

/// 채팅 창의 색. 대국·관전 화면은 어두운 색, 대국실의 로비 채팅은 밝은 색이다(`docs/screens.md`의 대국실).
enum ChatStyle { dark, light }

class _ChatColors {
  final Color text;
  final Color subText;
  final Color bubble;
  final Color myBubble;
  final Color onMyBubble;
  final Color field;
  final Color chip;

  const _ChatColors({
    required this.text,
    required this.subText,
    required this.bubble,
    required this.myBubble,
    required this.onMyBubble,
    required this.field,
    required this.chip,
  });

  static const dark = _ChatColors(
    text: GameColors.text,
    subText: GameColors.subText,
    bubble: GameColors.raisedButton,
    myBubble: GameColors.accent,
    onMyBubble: GameColors.onAccent,
    field: GameColors.surface,
    chip: GameColors.raisedButton,
  );

  static const light = _ChatColors(
    text: LightColors.text,
    subText: LightColors.subText,
    bubble: LightColors.surface,
    myBubble: LightColors.accent,
    onMyBubble: Colors.white,
    field: LightColors.surface,
    chip: LightColors.accentSurface,
  );

  static _ChatColors of(ChatStyle style) => switch (style) {
    ChatStyle.dark => dark,
    ChatStyle.light => light,
  };
}

/// 대국·관전 화면에서 채팅을 아래에서 올라오는 창으로 연다(`docs/screens.md`의 채팅). 판 윗부분이 보이도록 화면의 절반쯤 높이다.
Future<void> showChatSheet(BuildContext context, List<ChatManager> chats) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ChatSheet(chats: chats),
  );
}

class _ChatSheet extends StatelessWidget {
  final List<ChatManager> chats;

  const _ChatSheet({required this.chats});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // 자판이 올라오면 그만큼 위로 밀고, 화면이 낮으면 자판 위에 남는 높이에 맞춘다.
    final height = max(240.0, min(size.height * 0.55, size.height - keyboard - 80));
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ChatView(chats: chats, style: ChatStyle.dark),
          ),
        ),
      ),
    );
  }
}

/// 채팅 창. [chats]가 여럿이면 위에 고르는 칩을 둔다(대국이 끝난 대국자의 대국 채팅과 관전 채팅).
///
/// 다른 사람 메시지는 왼쪽에 닉네임과 함께, 내 메시지는 오른쪽 강조색 말풍선으로 보여준다. 다른 사람 메시지를 길게 누르면
/// 신고·차단 메뉴를 띄우고, 그냥 누르면 아무 일도 하지 않는다. 보내지 못한 메시지와 신고·차단 결과는 가운데 회색 안내로 알린다.
/// 로그인하지 않았으면(관전) 메시지 대신 로그인 안내를 보여준다.
class ChatView extends StatefulWidget {
  final List<ChatManager> chats;
  final ChatStyle style;

  const ChatView({super.key, required this.chats, required this.style});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  // 앱을 켠 뒤 처음 연 채팅 창에만 길게 누르기 안내를 보여준다.
  static var _hintShown = false;

  final _controller = TextEditingController();
  var _selected = 0;
  late final bool _showHint;

  @override
  void initState() {
    super.initState();
    _showHint = !_hintShown;
    _hintShown = true;
    // 창을 그리는 중에 새 메시지 수를 바꾸지 않도록 첫 화면을 그린 뒤 연 것으로 표시한다.
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
  }

  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldChat = oldWidget.chats[min(_selected, oldWidget.chats.length - 1)];
    if (_selected >= widget.chats.length) {
      _selected = 0;
    }
    if (oldChat != _chat) {
      oldChat.setOpen(false);
      WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
    }
  }

  @override
  void dispose() {
    for (final chat in widget.chats) {
      chat.setOpen(false);
    }
    _controller.dispose();
    super.dispose();
  }

  ChatManager get _chat => widget.chats[_selected];

  _ChatColors get _colors => _ChatColors.of(widget.style);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _chat, builder: _buildContent);
  }

  Widget _buildContent(BuildContext context, Widget? child) {
    final chat = _chat;
    if (!chat.signedIn) {
      return _buildLoginGuide(context);
    }
    final header = _buildHeader(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?header,
        if (_showHint) _NoticeLine(text: AppLocalizations.of(context).chatLongPressHint, colors: _colors),
        Expanded(child: _buildMessages(context)),
        const SizedBox(height: 8),
        _buildPhrases(context),
        const SizedBox(height: 8),
        _buildInput(context),
      ],
    );
  }

  /// 채팅 고르기 칩과 대국 채팅의 상대 채팅 끄기. 둘 다 없으면 null.
  Widget? _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chats = widget.chats;
    final chat = _chat;
    if (chats.length < 2 && chat.channel != ChatChannel.game) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // 좁은 화면에서는 상대 채팅 끄기가 칩 아래 줄로 내려간다.
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (chats.length > 1)
            for (var i = 0; i < chats.length; i++)
              ChoiceChip(
                // 대국 채팅 / 관전 채팅 / 로비 채팅
                label: Text(getChatChannelLabel(l10n, chats[i].channel)),
                selected: i == _selected,
                onSelected: (_) => _onSelectChat(i),
              ),
          if (chat.channel == ChatChannel.game)
            TextButton.icon(
              onPressed: chat.toggleOpponentMuted,
              style: TextButton.styleFrom(foregroundColor: _colors.subText, minimumSize: const Size(48, 48)),
              icon: Icon(chat.opponentMuted ? Icons.chat_bubble_outline : Icons.speaker_notes_off_outlined),
              // 상대 채팅 켜기 / 상대 채팅 끄기
              label: Text(chat.opponentMuted ? l10n.chatOpponentUnmute : l10n.chatOpponentMute),
            ),
        ],
      ),
    );
  }

  Widget _buildMessages(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chat = _chat;
    if (!chat.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = chat.items;
    if (items.isEmpty) {
      return Center(
        child: Text(
          // 아직 메시지가 없어요
          l10n.chatEmpty,
          style: TextStyle(fontSize: AppTextSizes.body, color: _colors.subText),
        ),
      );
    }
    // 새 메시지가 아래에 붙고 처음부터 맨 아래가 보이도록 거꾸로 쌓는다.
    return ListView.builder(
      reverse: true,
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItem(items[items.length - 1 - index]),
    );
  }

  Widget _buildItem(ChatItem item) {
    return switch (item) {
      ChatMessageItem() => _MessageBubble(
        item: item,
        colors: _colors,
        onLongPress: item.mine ? null : () => _onMessageLongPress(item.entry),
      ),
      ChatNoticeItem() => _NoticeLine(text: item.text, colors: _colors),
    };
  }

  /// 입력칸 위의 자주 쓰는 말. 누르면 바로 보낸다.
  Widget _buildPhrases(BuildContext context) {
    final phrases = getChatPhrases(AppLocalizations.of(context), _chat.channel);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final phrase in phrases)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(phrase, style: TextStyle(color: _colors.text)),
                backgroundColor: _colors.chip,
                side: BorderSide.none,
                onPressed: _chat.sending ? null : () => _onPhrase(phrase),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            maxLength: chatMaxLength,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _onSubmit(),
            style: TextStyle(fontSize: AppTextSizes.body, color: _colors.text),
            decoration: InputDecoration(
              // 메시지를 입력하세요
              hintText: l10n.chatInputHint,
              counterText: '',
              filled: true,
              fillColor: _colors.field,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(valueListenable: _controller, builder: _buildSendButton),
      ],
    );
  }

  Widget _buildSendButton(BuildContext context, TextEditingValue value, Widget? child) {
    final canSend = value.text.trim().isNotEmpty && !_chat.sending;
    return IconButton.filled(
      onPressed: canSend ? _onSubmit : null,
      style: IconButton.styleFrom(minimumSize: const Size(minTouchSize, minTouchSize)),
      icon: const Icon(Icons.send),
      // 보내기
      tooltip: AppLocalizations.of(context).chatSend,
    );
  }

  Widget _buildLoginGuide(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, color: _colors.subText),
          const SizedBox(height: 8),
          Text(
            // 로그인하면 채팅할 수 있어요
            l10n.chatLoginGuide,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: AppTextSizes.body, color: _colors.subText),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _onLogin,
            // 로그인
            child: Text(l10n.login),
          ),
        ],
      ),
    );
  }

  void _onFirstFrame(Duration timeStamp) {
    if (mounted) {
      _chat.setOpen(true);
    }
  }

  void _onSelectChat(int index) {
    if (index == _selected) {
      return;
    }
    _chat.setOpen(false);
    setState(() {
      _selected = index;
    });
    _chat.setOpen(true);
  }

  Future<void> _onLogin() async {
    await ensureSignedInWithProfile(context, LoginPurpose.spectateChat);
  }

  Future<void> _onSubmit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    final chat = _chat;
    if (!await _ensureProfile()) {
      return;
    }
    try {
      await chat.send(text);
      _controller.clear();
    } catch (error, stackTrace) {
      // 걸린 메시지를 고쳐 보낼 수 있도록 입력칸은 그대로 둔다.
      _onSendError(chat, error, stackTrace);
    }
  }

  Future<void> _onPhrase(String phrase) async {
    final chat = _chat;
    if (!await _ensureProfile()) {
      return;
    }
    try {
      await chat.send(phrase);
    } catch (error, stackTrace) {
      _onSendError(chat, error, stackTrace);
    }
  }

  /// 닉네임을 정하지 않았으면(관전) 정하게 한다. 보낼 수 있으면 true.
  Future<bool> _ensureProfile() async {
    if (managers.authManager.profile != null) {
      return true;
    }
    final ready = await ensureSignedInWithProfile(context, LoginPurpose.spectateChat);
    return ready && mounted;
  }

  void _onSendError(ChatManager chat, Object error, StackTrace stackTrace) {
    developer.log('ChatManager.send 실패', error: error, stackTrace: stackTrace);
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    // 부적절한 표현이 있어 보내지 않았어요 / 메시지를 보내지 못했어요. 잠시 후 다시 해 주세요
    chat.addNotice(error is AppException ? error.getMessage(l10n) : l10n.errorChatSend);
  }

  Future<void> _onMessageLongPress(ChatEntry entry) async {
    final action = await _showMessageMenu(entry.message.nickname);
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MessageAction.report:
        await _report(entry);
      case _MessageAction.block:
        await _block(entry);
    }
  }

  Future<_MessageAction?> _showMessageMenu(String nickname) {
    if (widget.style == ChatStyle.dark) {
      return showGameSheet<_MessageAction>(context, builder: (context) => _MessageMenu(nickname: nickname));
    }
    return showFormSheet<_MessageAction>(context, builder: (context) => _MessageMenu(nickname: nickname));
  }

  Future<void> _report(ChatEntry entry) async {
    final chat = _chat;
    final l10n = AppLocalizations.of(context);
    try {
      await chat.report(entry.id);
      // 신고했어요. 운영진이 확인할게요
      chat.addNotice(l10n.chatReportDone);
    } catch (error, stackTrace) {
      developer.log('ChatManager.report 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 신고하지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: l10n.errorChatReport);
      }
    }
  }

  /// 확인을 한 번 더 받고 차단한다. 차단한 사람의 메시지는 바로 숨겨진다.
  Future<void> _block(ChatEntry entry) async {
    final chat = _chat;
    final l10n = AppLocalizations.of(context);
    final nickname = entry.message.nickname;
    final confirmed = await DialogUtils.showConfirm(
      context,
      // {nickname}님을 차단할까요? 이 사람의 메시지와 대국 신청이 보이지 않아요
      message: l10n.blockConfirm(nickname),
      // 차단하기
      confirmLabel: l10n.blockAction,
    );
    final uid = managers.authManager.uid;
    if (!confirmed || !mounted || uid == null) {
      return;
    }
    try {
      await repositories.userBlockRepository.createBlock(uid, entry.message.uid);
      // {nickname}님을 차단했어요
      chat.addNotice(l10n.blockDone(nickname));
    } catch (error, stackTrace) {
      developer.log('UserBlockRepository.createBlock 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 차단하지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: l10n.errorBlock);
      }
    }
  }
}

/// 채팅 종류의 이름. 채팅 고르기 칩에 쓴다.
String getChatChannelLabel(AppLocalizations l10n, ChatChannel channel) => switch (channel) {
  // 로비 채팅
  ChatChannel.lobby => l10n.chatLobby,
  // 대국 채팅
  ChatChannel.game => l10n.chatGame,
  // 관전 채팅
  ChatChannel.spectator => l10n.spectateChat,
};

/// 입력칸 위의 자주 쓰는 말(`docs/screens.md`의 채팅).
List<String> getChatPhrases(AppLocalizations l10n, ChatChannel channel) => switch (channel) {
  ChatChannel.lobby => [
    // 안녕하세요
    l10n.chatPhraseHello,
    // 반갑습니다
    l10n.chatPhraseNiceToMeet,
    // 한 판 두실 분 계세요?
    l10n.chatPhraseLookingForGame,
  ],
  ChatChannel.game => [
    // 안녕하세요
    l10n.chatPhraseHello,
    // 잘 부탁드립니다
    l10n.chatPhraseGoodLuck,
    // 수고하셨습니다
    l10n.chatPhraseGoodGame,
  ],
  ChatChannel.spectator => [
    // 좋은 수네요
    l10n.chatPhraseNiceMove,
    // 응원합니다
    l10n.chatPhraseCheer,
  ],
};

enum _MessageAction { report, block }

/// 다른 사람 메시지를 길게 눌렀을 때의 신고·차단 메뉴.
class _MessageMenu extends StatelessWidget {
  final String nickname;

  const _MessageMenu({required this.nickname});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Text(
                nickname,
                style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              minTileHeight: 56,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.flag_outlined),
              // 신고하기
              title: Text(l10n.chatReport, style: const TextStyle(fontSize: AppTextSizes.body)),
              onTap: () => Navigator.of(context).pop(_MessageAction.report),
            ),
            ListTile(
              minTileHeight: 56,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.block),
              // 차단하기
              title: Text(l10n.blockAction, style: const TextStyle(fontSize: AppTextSizes.body)),
              onTap: () => Navigator.of(context).pop(_MessageAction.block),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageItem item;
  final _ChatColors colors;

  /// 다른 사람 메시지를 길게 눌렀을 때. 내 메시지면 null이다.
  final VoidCallback? onLongPress;

  const _MessageBubble({required this.item, required this.colors, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final message = item.entry.message;
    final mine = item.mine;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: mine ? colors.myBubble : colors.bubble, borderRadius: BorderRadius.circular(16)),
      child: Text(
        message.text,
        style: TextStyle(fontSize: AppTextSizes.body, color: mine ? colors.onMyBubble : colors.text),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                message.nickname,
                style: TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700, color: colors.subText),
              ),
            ),
          GestureDetector(onLongPress: onLongPress, child: bubble),
        ],
      ),
    );
  }
}

/// 가운데 회색 안내 한 줄.
class _NoticeLine extends StatelessWidget {
  final String text;
  final _ChatColors colors;

  const _NoticeLine({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: AppTextSizes.body, color: colors.subText),
      ),
    );
  }
}

/// 대국·관전 화면 버튼 줄의 채팅 버튼. 새 메시지 수를 아이콘 위에 보여주고, 누르면 채팅 창을 연다.
class ChatBarButton extends StatelessWidget {
  final List<ChatManager> chats;
  final String label;

  const ChatBarButton({super.key, required this.chats, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: Listenable.merge(chats), builder: _buildButton);
  }

  Widget _buildButton(BuildContext context, Widget? child) {
    return GameBarButton(
      icon: Icons.chat_bubble_outline,
      label: label,
      badgeCount: getUnreadCount(chats),
      onPressed: () => showChatSheet(context, chats),
    );
  }
}

/// 대국 결과 창의 채팅 버튼. 결과 창을 닫지 않고 채팅 창을 위에 연다.
class ChatTextButton extends StatelessWidget {
  final List<ChatManager> chats;

  const ChatTextButton({super.key, required this.chats});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: Listenable.merge(chats), builder: _buildButton);
  }

  Widget _buildButton(BuildContext context, Widget? child) {
    final count = getUnreadCount(chats);
    return TextButton.icon(
      onPressed: () => showChatSheet(context, chats),
      style: TextButton.styleFrom(foregroundColor: GameColors.buttonText, minimumSize: const Size(48, 48)),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: GameColors.accent,
        textColor: GameColors.onAccent,
        child: const Icon(Icons.chat_bubble_outline),
      ),
      // 채팅
      label: Text(AppLocalizations.of(context).chat, style: const TextStyle(fontSize: AppTextSizes.body)),
    );
  }
}

/// [chats]의 새 메시지 수 합계.
int getUnreadCount(List<ChatManager> chats) {
  var count = 0;
  for (final chat in chats) {
    count += chat.unreadCount;
  }
  return count;
}
