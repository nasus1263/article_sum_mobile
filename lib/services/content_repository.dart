import '../models/content_record.dart';
import 'supabase_client_provider.dart';

/// Read-only access to the `contents` table, mirroring electron/db.js's
/// `listByStatus`. Only the queries backing Pending/Archive display are
/// implemented on mobile. Rows are scoped by RLS to the signed-in user,
/// so this returns nothing until Chat/Archive/Pending's auth gate passes.
class ContentRepository {
  Future<List<ContentRecord>> listByStatus(String status) async {
    final client = await SupabaseClientProvider.getClient();
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
