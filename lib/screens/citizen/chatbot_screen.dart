import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/services/ai_chatbot.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/faqs.dart';

/// Barangay Assistant — an AI chatbot for information queries, paired with an
/// offline, locale-aware FAQ list.
///
/// The assistant answers questions about documents, payment, incident
/// reporting, announcements and document verification via the `chatbot` AI
/// task. Its copy and FAQ content follow the active app locale (English /
/// Filipino / Cebuano). When the AI is unavailable (offline, quota, any
/// failure) the screen falls back to [matchFaq] against the local FAQ table, so
/// a citizen always gets an answer for common questions.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final AiChatbot _chatbot = AiChatbot();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  /// Conversation turns after the welcome message. Null [ _suggestions] means
  /// "show the localized welcome suggestions".
  final List<ChatMessage> _messages = <ChatMessage>[];
  List<String>? _suggestions;
  bool _isSending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  String get _languageCode => Localizations.localeOf(context).languageCode;

  Future<void> _send(
    String rawText, {
    required AppLocalizations l10n,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty || _isSending) return;

    final history = List<ChatMessage>.of(_messages);
    final language = _languageCode;
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      _suggestions = const <String>[];
      _isSending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final reply = await _chatbot.ask(
      message: text,
      history: history,
      language: language,
    );

    if (!mounted) return;

    if (reply != null) {
      setState(() {
        _messages.add(ChatMessage(role: ChatRole.assistant, text: reply.reply));
        _suggestions = reply.suggestions;
        _isSending = false;
      });
      _scrollToBottom();
      return;
    }

    // AI unavailable — answer from the offline FAQ list when we can.
    final faq = matchFaq(text, languageCode: language);
    final fallback = faq != null
        ? '${faq.answer}\n\n${l10n.chatbotFaqFallbackNotice}'
        : l10n.chatbotUnavailable;
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.assistant, text: fallback));
      _suggestions = null;
      _isSending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _openFaqSheet(AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FaqSheet(
        l10n: l10n,
        faqs: faqsFor(_languageCode),
        onAsk: (question) {
          Navigator.of(context).pop();
          _send(question, l10n: l10n);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suggestions =
        _suggestions ?? welcomeSuggestionsFor(_languageCode);
    final welcome = ChatMessage(
      role: ChatRole.assistant,
      text: l10n.chatbotWelcome,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(l10n),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              // Index 0 is the locale-aware welcome bubble; the rest are turns.
              itemCount: 1 + _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _MessageBubble(message: welcome);
                }
                final messageIndex = index - 1;
                if (messageIndex >= _messages.length) {
                  return const _TypingBubble();
                }
                return _MessageBubble(message: _messages[messageIndex]);
              },
            ),
          ),
          if (suggestions.isNotEmpty && !_isSending)
            _buildSuggestionChips(suggestions, l10n),
          _buildInputBar(l10n),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1565C0),
            Color(0xFF1976D2),
            Color(0xFF42A5F5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: l10n.commonBack,
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(
                    Icons.support_agent,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.chatbotTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.chatbotSubtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openFaqSheet(l10n),
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: l10n.chatbotBrowseFaqs,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(
    List<String> suggestions,
    AppLocalizations l10n,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions
            .map(
              (suggestion) => ActionChip(
                label: Text(suggestion),
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
                onPressed: () => _send(suggestion, l10n: l10n),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildInputBar(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocus,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(600),
                  ],
                  onSubmitted: (value) => _send(value, l10n: l10n),
                  decoration: InputDecoration(
                    hintText: l10n.chatbotInputHint,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                enabled: !_isSending,
                tooltip: l10n.chatbotSendTooltip,
                onPressed: () => _send(_inputController.text, l10n: l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? AppColors.primary : Colors.grey.shade300,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: isUser
            ? null
            : Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: isUser
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Text(
        message.text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.4,
          color: isUser ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: Color(0xFFE3F2FD),
                shape: BoxShape.circle,
              ),
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(
                  Icons.support_agent,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(
                Icons.support_agent,
                color: AppColors.primary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

/// Three dots that fade in sequence while the assistant is thinking.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (index) {
            final phase = (_controller.value + index * 0.2) % 1.0;
            final opacity =
                0.3 + 0.7 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Bottom sheet listing every localized FAQ. Each entry expands to its answer
/// and can be sent straight to the assistant.
class _FaqSheet extends StatelessWidget {
  const _FaqSheet({
    required this.l10n,
    required this.faqs,
    required this.onAsk,
  });

  final AppLocalizations l10n;
  final List<FaqEntry> faqs;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.help_outline,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.chatbotFaqSheetTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: faqs.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: Colors.grey.withValues(alpha: 0.12),
              ),
              itemBuilder: (context, index) {
                final faq = faqs[index];
                return ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  title: Text(
                    faq.question,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  iconColor: AppColors.primary,
                  collapsedIconColor: Colors.grey.shade500,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        faq.answer,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => onAsk(faq.question),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: Text(l10n.chatbotAskAssistant),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
