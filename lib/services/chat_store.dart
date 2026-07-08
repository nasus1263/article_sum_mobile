import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

/// On-device chat session persistence — mirrors electron/chatStore.js's
/// chats.json, but keyed to this device instead of a shared backend.
class ChatStore {
  static const _storageKey = 'chat_sessions';

  static Future<Map<String, dynamic>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  static Future<void> _saveAll(Map<String, dynamic> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(sessions));
  }

  static Future<ChatSession> getSession(int contentId) async {
    final all = await _loadAll();
    final raw = all[contentId.toString()];
    if (raw == null) return ChatSession.empty;
    return ChatSession.fromJson((raw as Map).cast<String, dynamic>());
  }

  static Future<List<ChatSessionSummary>> listSessions() async {
    final all = await _loadAll();
    return all.entries.map((e) {
      final session = ChatSession.fromJson((e.value as Map).cast<String, dynamic>());
      return ChatSessionSummary(
        contentId: int.parse(e.key),
        provider: session.provider,
        updatedAt: session.updatedAt,
        lastMessage: session.messages.isNotEmpty ? session.messages.last.content : null,
      );
    }).toList();
  }

  static Future<void> appendMessage(int contentId, ChatMessage message) async {
    final all = await _loadAll();
    final key = contentId.toString();
    final existing = all[key] != null
        ? ChatSession.fromJson((all[key] as Map).cast<String, dynamic>())
        : ChatSession.empty;
    final updated = ChatSession(
      messages: [...existing.messages, message],
      provider: existing.provider,
      updatedAt: message.createdAt,
    );
    all[key] = updated.toJson();
    await _saveAll(all);
  }

  static Future<void> setProvider(int contentId, String provider) async {
    final all = await _loadAll();
    final key = contentId.toString();
    final existing = all[key] != null
        ? ChatSession.fromJson((all[key] as Map).cast<String, dynamic>())
        : ChatSession.empty;
    all[key] = ChatSession(messages: existing.messages, provider: provider, updatedAt: existing.updatedAt)
        .toJson();
    await _saveAll(all);
  }

  static Future<void> deleteSession(int contentId) async {
    final all = await _loadAll();
    all.remove(contentId.toString());
    await _saveAll(all);
  }
}
