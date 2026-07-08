import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';

const _timeout = Duration(seconds: 60);

Future<void> _consumeSSE(
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
}

/// Streams a chat reply from the backend's /chat endpoint (SSE), mirroring
/// electron/llm.js's streamChat. The backend holds the Claude API key.
Future<String> streamChat({
  required String backendUrl,
  required String articleText,
  required List<ChatMessage> history,
  required void Function(String chunk) onChunk,
}) async {
  final request = http.Request('POST', Uri.parse('$backendUrl/chat'))
    ..headers['Content-Type'] = 'application/json'
    ..body = jsonEncode({
      'articleText': articleText,
      'messages': history.map((m) => {'role': m.role, 'content': m.content}).toList(),
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
