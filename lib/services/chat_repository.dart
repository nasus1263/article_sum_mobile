import '../models/chat_models.dart';
import 'supabase_client_provider.dart';

/// Access to the `chat_sessions` table (one row per content_id), mirroring
/// electron/chatStore.js (article-sum commit b2b35ae, "chat: 채팅 기록 저장을
/// 로컬 파일에서 Supabase로 전환"). Replaces the old SharedPreferences-based
/// ChatStore so history syncs across devices. Schema per
/// docs/260708_232305 chat 기록 supabase 전환.md: content_id (PK), user_id
/// (default auth.uid()), messages jsonb, provider, updated_at — scoped by
/// RLS to the signed-in user. Upserts only send the columns being changed
/// (last-write-wins per that doc's concurrency policy), so unrelated
/// columns on an existing row are left untouched.
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
        .select('content_id, messages, provider, updated_at');
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
    final client = await SupabaseClientProvider.getClient();
    final row = await client
        .from('chat_sessions')
        .select('messages')
        .eq('content_id', contentId)
        .maybeSingle();
    final messages = [
      ...((row?['messages'] as List?) ?? []).cast<Map<String, dynamic>>(),
      message.toJson(),
    ];
    await client.from('chat_sessions').upsert({
      'content_id': contentId,
      'messages': messages,
      'updated_at': message.createdAt,
    }, onConflict: 'content_id');
  }

  Future<void> setProvider(int contentId, String provider) async {
    final client = await SupabaseClientProvider.getClient();
    await client.from('chat_sessions').upsert({
      'content_id': contentId,
      'provider': provider,
    }, onConflict: 'content_id');
  }

  Future<void> deleteSession(int contentId) async {
    final client = await SupabaseClientProvider.getClient();
    await client.from('chat_sessions').delete().eq('content_id', contentId);
  }
}
