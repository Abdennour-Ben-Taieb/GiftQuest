import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/chat_message.dart';

/// Calls the Groq chat-completions API (OpenAI-compatible), mirroring the
/// Kotlin app's GroqApiClient — including its 429 retry/backoff behavior.
class GroqApiClient {
  GroqApiClient._();

  static final Uri _endpoint = Uri.parse(
    'https://api.groq.com/openai/v1/chat/completions',
  );

  static Future<String> call({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
    required String model,
    int retryCount = 0,
  }) async {
    if (!AppConfig.hasGroqApiKey) {
      return "The gift-guessing game isn't configured yet — no Groq API key.";
    }

    try {
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        for (final msg in history)
          {
            'role': msg.sender == Sender.user ? 'user' : 'assistant',
            'content': msg.text,
          },
        {'role': 'user', 'content': userMessage},
      ];

      final response = await http
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.groqApiKey}',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'max_tokens': 300,
              'temperature': 0.8,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 429 && retryCount < 2) {
        await Future<void>.delayed(const Duration(seconds: 30));
        return call(
          systemPrompt: systemPrompt,
          history: history,
          userMessage: userMessage,
          model: model,
          retryCount: retryCount + 1,
        );
      }

      if (response.statusCode != 200) {
        developer.log(
          'Groq error ${response.statusCode}: ${response.body}',
          name: 'GiftQuest',
        );
        return 'Something went wrong (error ${response.statusCode}). Try again!';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = ((data['choices'] as List)
                  .first['message']['content']
              as String? ??
          '')
          .trim();

      if (content.isEmpty) {
        return "Hmm, I didn't catch that. Try asking again!";
      }
      return content;
    } catch (e) {
      developer.log('Groq exception: $e', name: 'GiftQuest');
      return "Couldn't connect. Check your internet and try again!";
    }
  }
}
