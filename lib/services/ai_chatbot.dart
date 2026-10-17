import 'package:guin_app/services/ai_service.dart';
import 'package:guin_app/utils/faqs.dart';

/// Who authored a chat turn.
enum ChatRole { user, assistant }

/// One message in the Barangay Assistant transcript. Kept deliberately small so
/// it can be serialized into the `chatbot` task payload as conversation history.
class ChatMessage {
  const ChatMessage({required this.role, required this.text});

  final ChatRole role;
  final String text;

  bool get isUser => role == ChatRole.user;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role == ChatRole.user ? 'user' : 'assistant',
    'text': text,
  };
}

/// A parsed `chatbot` result: the assistant's reply plus optional follow-up
/// question suggestions.
class ChatbotReply {
  const ChatbotReply({required this.reply, required this.suggestions});

  final String reply;
  final List<String> suggestions;

  /// Pure parser for the edge function's `result` map. Returns null when the
  /// reply is missing or empty so callers fall back to the offline FAQ path.
  /// Malformed fields are coerced safely.
  static ChatbotReply? fromResult(Map<String, dynamic>? result) {
    if (result == null) return null;

    final rawReply = result['reply'];
    final reply = rawReply is String ? rawReply.trim() : '';
    if (reply.isEmpty) return null;

    final suggestions = <String>[];
    final rawSuggestions = result['suggestions'];
    if (rawSuggestions is List) {
      for (final item in rawSuggestions) {
        if (item is String && item.trim().isNotEmpty) {
          suggestions.add(item.trim());
        }
        if (suggestions.length >= 3) break;
      }
    }

    return ChatbotReply(reply: reply, suggestions: suggestions);
  }
}

/// Client for the `chatbot` AI task on the `ai` edge function.
///
/// Degrades gracefully: any failure (AI unavailable, slow, quota exhausted,
/// bad payload) yields null and the caller answers from the offline FAQ list
/// instead. The core workflow is never blocked by an AI failure.
class AiChatbot {
  AiChatbot({AiService? aiService}) : _aiService = aiService ?? AiService();

  final AiService _aiService;

  /// Sends [message] with optional recent [history] and grounded [faqs].
  ///
  /// When [faqs] is omitted the localized FAQ list for [language] is sent, so
  /// the assistant answers using the same FAQ content the screen displays.
  /// Returns null on any failure.
  Future<ChatbotReply?> ask({
    required String message,
    List<ChatMessage> history = const <ChatMessage>[],
    List<FaqEntry>? faqs,
    String? language,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return null;

    final resolvedFaqs = faqs ?? faqsFor(language);
    final result = await _aiService.invoke(
      'chatbot',
      <String, dynamic>{
        'message': trimmed,
        'history': history.map((m) => m.toJson()).toList(),
        'faqs': resolvedFaqs.map((f) => f.toJson()).toList(),
        if (language != null && language.isNotEmpty) 'language': language,
      },
      timeout: const Duration(seconds: 20),
    );
    return ChatbotReply.fromResult(result);
  }
}
