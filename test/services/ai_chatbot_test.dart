import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/services/ai_chatbot.dart';
import 'package:guin_app/utils/faqs.dart';

void main() {
  group('ChatMessage', () {
    test('serializes the user role', () {
      const message = ChatMessage(role: ChatRole.user, text: 'hello');
      expect(message.isUser, isTrue);
      expect(message.toJson(), <String, dynamic>{
        'role': 'user',
        'text': 'hello',
      });
    });

    test('serializes the assistant role', () {
      const message = ChatMessage(role: ChatRole.assistant, text: 'hi there');
      expect(message.isUser, isFalse);
      expect(message.toJson(), <String, dynamic>{
        'role': 'assistant',
        'text': 'hi there',
      });
    });
  });

  group('ChatbotReply.fromResult', () {
    test('parses a full result', () {
      final reply = ChatbotReply.fromResult(<String, dynamic>{
        'reply': 'Open Request Document from your dashboard.',
        'suggestions': ['How much does it cost?', 'How long does it take?'],
      });

      expect(reply, isNotNull);
      expect(reply!.reply, 'Open Request Document from your dashboard.');
      expect(reply.suggestions, [
        'How much does it cost?',
        'How long does it take?',
      ]);
    });

    test('returns null when the result map is null', () {
      expect(ChatbotReply.fromResult(null), isNull);
    });

    test('returns null when the reply is missing or blank', () {
      expect(ChatbotReply.fromResult(<String, dynamic>{}), isNull);
      expect(
        ChatbotReply.fromResult(<String, dynamic>{'reply': '   '}),
        isNull,
      );
      expect(
        ChatbotReply.fromResult(<String, dynamic>{'reply': 42}),
        isNull,
      );
    });

    test('tolerates a missing or malformed suggestions list', () {
      final noSuggestions = ChatbotReply.fromResult(<String, dynamic>{
        'reply': 'Sure.',
      });
      expect(noSuggestions!.suggestions, isEmpty);

      final malformed = ChatbotReply.fromResult(<String, dynamic>{
        'reply': 'Sure.',
        'suggestions': <dynamic>['ok', 7, '', '  ', 'also ok'],
      });
      expect(malformed!.suggestions, ['ok', 'also ok']);
    });

    test('caps suggestions at three', () {
      final reply = ChatbotReply.fromResult(<String, dynamic>{
        'reply': 'Sure.',
        'suggestions': <dynamic>['a', 'b', 'c', 'd', 'e'],
      });
      expect(reply!.suggestions, ['a', 'b', 'c']);
    });
  });

  group('FAQ content', () {
    test('every entry has a question, answer and category', () {
      for (final faqs in <List<FaqEntry>>[kFaqsEn, kFaqsFil, kFaqsCeb]) {
        expect(faqs, isNotEmpty);
        for (final faq in faqs) {
          expect(faq.question.trim(), isNotEmpty);
          expect(faq.answer.trim(), isNotEmpty);
        }
      }
    });

    test('all locales define the same number of entries', () {
      expect(kFaqsFil.length, kFaqsEn.length);
      expect(kFaqsCeb.length, kFaqsEn.length);
    });

    test('questions are unique within each locale', () {
      for (final faqs in <List<FaqEntry>>[kFaqsEn, kFaqsFil, kFaqsCeb]) {
        final questions = faqs.map((f) => f.question).toSet();
        expect(questions.length, faqs.length);
      }
    });

    test('serializes to the payload shape the edge function expects', () {
      final json = kFaqsEn.first.toJson();
      expect(json.keys, containsAll(<String>['question', 'answer', 'category']));
      expect(json['question'], isA<String>());
      expect(json['category'], isA<String>());
    });

    test('faqsFor resolves each locale and falls back to English', () {
      expect(faqsFor('en'), same(kFaqsEn));
      expect(faqsFor('fil'), same(kFaqsFil));
      expect(faqsFor('ceb'), same(kFaqsCeb));
      expect(faqsFor('de'), same(kFaqsEn));
      expect(faqsFor(null), same(kFaqsEn));
    });

    test('welcome suggestions are localized and non-empty', () {
      for (final code in <String?>['en', 'fil', 'ceb', 'zz']) {
        final suggestions = welcomeSuggestionsFor(code);
        expect(suggestions, hasLength(3));
        for (final suggestion in suggestions) {
          expect(suggestion.trim(), isNotEmpty);
        }
      }
      // The localized suggestion must come from that locale's list.
      expect(faqsFor('fil').map((f) => f.question), contains(
        welcomeSuggestionsFor('fil').first,
      ));
    });
  });

  group('matchFaq', () {
    test('matches a request-phrasing question', () {
      final faq = matchFaq('how do I request a barangay clearance?');
      expect(faq, isNotNull);
      expect(faq!.category, FaqCategory.documents);
    });

    test('matches a payment question', () {
      final faq = matchFaq('how much is the fee and can I pay via gcash?');
      expect(faq, isNotNull);
      expect(faq!.category, FaqCategory.payment);
    });

    test('matches an incident question', () {
      final faq = matchFaq('I want to report an incident');
      expect(faq, isNotNull);
      expect(faq!.category, FaqCategory.incidents);
    });

    test('returns null for an unrelated query', () {
      expect(matchFaq('what is the capital of France'), isNull);
    });

    test('returns null for an empty query', () {
      expect(matchFaq('   '), isNull);
    });

    test('matches a Filipino query against the Filipino list', () {
      final faq = matchFaq(
        'paano ako magbabayad ng bayad gamit ang gcash?',
        languageCode: 'fil',
      );
      expect(faq, isNotNull);
      expect(faq!.category, FaqCategory.payment);
    });

    test('matches a Cebuano query against the Cebuano list', () {
      final faq = matchFaq(
        'unsaon pagreport og insidente?',
        languageCode: 'ceb',
      );
      expect(faq, isNotNull);
      expect(faq!.category, FaqCategory.incidents);
    });
  });
}
