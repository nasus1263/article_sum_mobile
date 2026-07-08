import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_record.dart';
import 'supabase_config.dart';

/// Read-only access to the `contents` table, mirroring electron/db.js's
/// `listByStatus`. Only the queries backing Pending/Archive display are
/// implemented on mobile.
class ContentRepository {
  SupabaseClient? _client;
  String? _clientKey;

  Future<SupabaseClient> _getClient() async {
    final config = await SupabaseConfigStore.load();
    if (!config.isConfigured) {
      throw Exception(
        'Supabase is not configured. Set the project URL and anon key in Settings.',
      );
    }
    final key = '${config.url}|${config.anonKey}';
    if (_client == null || _clientKey != key) {
      _client = SupabaseClient(config.url, config.anonKey);
      _clientKey = key;
    }
    return _client!;
  }

  Future<List<ContentRecord>> listByStatus(String status) async {
    final client = await _getClient();
    final rows = await client
        .from('contents')
        .select('id, url, tag, status, data, created_at')
        .eq('status', status)
        .order('id', ascending: status == 'pending');
    return (rows as List)
        .map((r) => ContentRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
