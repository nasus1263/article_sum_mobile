import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';

const _claudeBase = 'https://api.anthropic.com/v1';
const _geminiBase = 'https://generativelanguage.googleapis.com/v1beta';
const _openaiBase = 'https://api.openai.com/v1';
const _nvidiaBase = 'https://integrate.api.nvidia.com/v1';

const _maxTokens = 1024 * 10;
const _timeout = Duration(seconds: 60);

String _buildChatSystemPrompt(String articleText) {
  return 'You are a helpful assistant answering questions about the article below. '
      'Use it as your primary source of truth. If the question cannot be answered from the '
      'article, say so clearly.\n\nArticle:\n$articleText';
}

Future<String> _consumeSSE(
  http.StreamedResponse response,
  void Function(Map<String, dynamic> event) onEvent,
) async {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final body = await response.stream.bytesToString();
    throw Exception('HTTP ${response.statusCode}: $body');
  }
  var buffer = '';
  await for (final chunk in response.stream.transform(utf8.decoder)) {
    buffer += chunk;
    final lines = buffer.split('\n');
    buffer = lines.removeLast();
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        onEvent(jsonDecode(payload) as Map<String, dynamic>);
      } catch (_) {
        // ignore malformed/partial SSE payloads
      }
    }
  }
  return '';
}

Future<String> _streamClaudeChat(
  String systemPrompt,
  List<ChatMessage> history,
  String model,
  String key,
  void Function(String chunk) onChunk,
) async {
  final request = http.Request('POST', Uri.parse('$_claudeBase/messages'))
    ..headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
    })
    ..body = jsonEncode({
      'model': model,
      'max_tokens': _maxTokens,
      'system': systemPrompt,
      'messages': history.map((m) => {'role': m.role, 'content': m.content}).toList(),
      'stream': true,
    });
  final response = await http.Client().send(request).timeout(_timeout);
  final full = StringBuffer();
  await _consumeSSE(response, (event) {
    if (event['type'] == 'content_block_delta' && event['delta']?['type'] == 'text_delta') {
      final text = event['delta']['text'] as String;
      full.write(text);
      onChunk(text);
    }
  });
  return full.toString();
}

Future<String> _streamGeminiChat(
  String systemPrompt,
  List<ChatMessage> history,
  String model,
  String key,
  void Function(String chunk) onChunk,
) async {
  final contents = history
      .map((m) => {
            'role': m.role == 'assistant' ? 'model' : 'user',
            'parts': [
              {'text': m.content},
            ],
          })
      .toList();
  final request = http.Request(
    'POST',
    Uri.parse('$_geminiBase/models/$model:streamGenerateContent?alt=sse&key=$key'),
  )
    ..headers['Content-Type'] = 'application/json'
    ..body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': contents,
      'generationConfig': {'maxOutputTokens': _maxTokens},
    });
  final response = await http.Client().send(request).timeout(_timeout);
  final full = StringBuffer();
  await _consumeSSE(response, (event) {
    final candidates = event['candidates'] as List?;
    final text = candidates != null && candidates.isNotEmpty
        ? (candidates[0]['content']?['parts']?[0]?['text'] as String?)
        : null;
    if (text != null && text.isNotEmpty) {
      full.write(text);
      onChunk(text);
    }
  });
  return full.toString();
}

Future<String> _streamOpenAiCompatibleChat(
  String base,
  String systemPrompt,
  List<ChatMessage> history,
  String model,
  String key,
  void Function(String chunk) onChunk,
) async {
  final request = http.Request('POST', Uri.parse('$base/chat/completions'))
    ..headers.addAll({'Content-Type': 'application/json', 'Authorization': 'Bearer $key'})
    ..body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...history.map((m) => {'role': m.role, 'content': m.content}),
      ],
      'max_tokens': _maxTokens,
      'stream': true,
    });
  final response = await http.Client().send(request).timeout(_timeout);
  final full = StringBuffer();
  await _consumeSSE(response, (event) {
    final choices = event['choices'] as List?;
    final text = choices != null && choices.isNotEmpty
        ? (choices[0]['delta']?['content'] as String?)
        : null;
    if (text != null && text.isNotEmpty) {
      full.write(text);
      onChunk(text);
    }
  });
  return full.toString();
}

/// Streams a chat reply directly from the provider's API — no backend
/// server involved, mirroring electron/llm.js's streamChat but run
/// on-device with the user's own API key.
Future<String> streamChat({
  required String provider,
  required String articleText,
  required List<ChatMessage> history,
  required String model,
  required Map<String, String> apiKeys,
  required void Function(String chunk) onChunk,
}) async {
  final key = apiKeys[provider];
  if (key == null || key.isEmpty) {
    throw Exception('$provider API key is missing');
  }
  final systemPrompt = _buildChatSystemPrompt(articleText);

  switch (provider) {
    case 'claude':
      return _streamClaudeChat(systemPrompt, history, model, key, onChunk);
    case 'gemini':
      return _streamGeminiChat(systemPrompt, history, model, key, onChunk);
    case 'openai':
      return _streamOpenAiCompatibleChat(_openaiBase, systemPrompt, history, model, key, onChunk);
    default:
      return _streamOpenAiCompatibleChat(_nvidiaBase, systemPrompt, history, model, key, onChunk);
  }
}
