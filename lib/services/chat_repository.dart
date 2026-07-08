import '../models/chat_models.dart';
import 'supabase_client_provider.dart';

/// Access to the `chat_sessions` table (one row per content_id), replacing
/// the old SharedPreferences-based ChatStore so history syncs across
/// devices. Schema per docs/260708_185419 db 전면 개편 결정사항.md:
/// content_id (PK), user_id (default auth.uid()), messages jsonb, provider,
/// updated_at. Scoped by RLS to the signed-in user — run that doc's SQL
/// migration against the Supabase project before this table exists.
class ChatRepository {
  Future<ChatSession> getSession(int contentId) async {
    final client = await SupabaseClientProvider.getClient();
    final row = await client
        .from('chat_sessions')
        .select('messages, provider, updated_at')
        .eq('content_id', contentId)
        .maybeSingle();
    if (row == null) return ChatSession.empty;
    return ChatSession.fromJson({
      'messages': row['messages'],
      'provider': row['provider'],
      'updatedAt': row['updated_at'],
    });
  }

  Future<List<ChatSessionSummary>> listSessions() async {
    final client = await SupabaseClientProvider.getClient();
    final rows = await client
        .from('chat_sessions')
        .select('content_id, messages, provider, updated_at')
        .order('updated_at', ascending: false);
    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final messages = (row['messages'] as List?) ?? [];
      final last = messages.isNotEmpty ? (messages.last as Map) : null;
      return ChatSessionSummary(
        contentId: row['content_id'] as int,
        provider: row['provider'] as String?,
        updatedAt: row['updated_at'] as String?,
        lastMessage: last?['content'] as String?,
      );
    }).toList();
  }

  Future<void> appendMessage(int contentId, ChatMessage message) async {
    final session = await getSession(contentId);
    await _upsert(
      contentId,
      messages: [...session.messages, message],
      provider: session.provider,
      updatedAt: message.createdAt,
    );
  }

  Future<void> setProvider(int contentId, String provider) async {
    final session = await getSession(contentId);
    await _upsert(
      contentId,
      messages: session.messages,
      provider: provider,
      updatedAt: session.updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  Future<void> deleteSession(int contentId) async {
    final client = await SupabaseClientProvider.getClient();
    await client.from('chat_sessions').delete().eq('content_id', contentId);
  }

  Future<void> _upsert(
    int contentId, {
    required List<ChatMessage> messages,
    String? provider,
    required String updatedAt,
  }) async {
    final client = await SupabaseClientProvider.getClient();
    await client.from('chat_sessions').upsert({
      'content_id': contentId,
      'messages': messages.map((m) => m.toJson()).toList(),
      'provider': provider,
      'updated_at': updatedAt,
    });
  }
}
