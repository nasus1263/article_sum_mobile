import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/pipeline_defaults.dart';
import '../models/content_record.dart';
import 'supabase_client_provider.dart';

/// Access to the `contents` table, mirroring electron/db.js.
/// Scoped by RLS to the signed-in user.
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

  Future<void> approve(int id, {String? folder}) async {
    final client = await SupabaseClientProvider.getClient();
    final response = await client
        .from('contents')
        .select('data')
        .eq('id', id)
        .single();
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    data['folder'] = folder;
    
    await client.from('contents').update({
      'status': 'approved',
      'data': data,
    }).eq('id', id);
  }

  Future<void> discard(int id) async {
    final client = await SupabaseClientProvider.getClient();
    await client.from('contents').delete().eq('id', id);
  }

  Future<List<ContentRecord>> getRelated(int id) async {
    final client = await SupabaseClientProvider.getClient();
    final rows = await client.rpc('match_contents', params: {'source_id': id});
    return (rows as List)
        .map((r) => ContentRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> regenerateSummary(int id, String backendUrl) async {
    final client = await SupabaseClientProvider.getClient();
    final response = await client
        .from('contents')
        .select('id, url, tag, status, data, created_at')
        .eq('id', id)
        .single();
    final record = ContentRecord.fromJson(response);
    
    if (record.data.original == null) {
      throw Exception('Original article text is missing. Cannot regenerate.');
    }
    
    final data = Map<String, dynamic>.from(record.data.toJson());
    data['processing'] = true;
    data['stage'] = 'Regenerating summary...';
    await client.from('contents').update({'data': data}).eq('id', id);
    
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': record.data.original,
          'options': {
            'emoji': true,
            'kidFriendly': false,
            'language': 'ko',
          },
          'categories': kDefaultCategories,
        }),
      ).timeout(const Duration(seconds: 45));
      
      if (res.statusCode != 200) {
        throw Exception('Backend summarize failed: ${res.reasonPhrase}');
      }
      
      final result = jsonDecode(res.body) as Map<String, dynamic>;
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Summarization failed');
      }
      
      final summaries = Map<String, dynamic>.from(data['summaries'] as Map? ?? {});
      const optionKey = 'emoji';
      summaries[optionKey] = result['summary'];
      
      data['category'] = result['category'];
      data['summaries'] = summaries;
      data['processing'] = false;
      data.remove('stage');
      data.remove('error');
      
      await client.from('contents').update({'data': data}).eq('id', id);
    } catch (e) {
      data['processing'] = false;
      data.remove('stage');
      data['error'] = e.toString();
      await client.from('contents').update({'data': data}).eq('id', id);
      rethrow;
    }
  }
}
