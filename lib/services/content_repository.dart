import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/pipeline_defaults.dart';
import '../models/content_record.dart';
import 'pipeline_settings_store.dart';
import 'queue_events.dart';
import 'supabase_client_provider.dart';

/// Mirrors electron/main.js's computeOptionKey: the key summaries are keyed
/// by so re-running with the same options reuses the same summary slot.
String _optionKey(PipelineSettings settings) {
  final parts = <String>[];
  if (settings.emoji) parts.add('emoji');
  if (settings.kidFriendly) parts.add('child');
  return parts.isEmpty ? 'default' : parts.join('_');
}

/// Access to the `contents` table, mirroring electron/db.js.
/// Scoped by RLS to the signed-in user.
class ContentRepository {
  Future<List<ContentRecord>> listByStatus(String status) async {
    final client = await SupabaseClientProvider.getClient();
    final rows = await client
        .from('contents')
        .select('id, url, tag, status, data, embedding, favorited_at, created_at')
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

    await client
        .from('contents')
        .update({'status': 'approved', 'data': data})
        .eq('id', id);
  }

  Future<void> discard(int id) async {
    final client = await SupabaseClientProvider.getClient();
    await client.from('contents').delete().eq('id', id);
  }

  Future<void> setFavorite(int id, bool favorited) async {
    final client = await SupabaseClientProvider.getClient();
    await client
        .from('contents')
        .update({
          'favorited_at': favorited ? DateTime.now().toUtc().toIso8601String() : null,
        })
        .eq('id', id);
  }

  Future<List<ContentRecord>> getRelated(int id) async {
    final client = await SupabaseClientProvider.getClient();
    final rows = await client.rpc(
      'match_contents',
      params: {'source_id': id, 'match_count': 5},
    );
    return (rows as List)
        .map((r) => ContentRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> regenerateSummary(
    int id,
    String backendUrl, {
    required PipelineSettings settings,
    Future<void> Function()? onProcessingStarted,
  }) async {
    final client = await SupabaseClientProvider.getClient();
    final response = await client
        .from('contents')
        .select('id, url, tag, status, data, embedding, favorited_at, created_at')
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
    await onProcessingStarted?.call();

    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/summarize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': record.data.original,
              'options': {
                'emoji': settings.emoji,
                'kidFriendly': settings.kidFriendly,
                'language': settings.language,
              },
              'categories': kDefaultCategories,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (res.statusCode != 200) {
        throw Exception('Backend summarize failed: ${res.reasonPhrase}');
      }

      final result = jsonDecode(res.body) as Map<String, dynamic>;
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Summarization failed');
      }

      final summaries = Map<String, dynamic>.from(
        data['summaries'] as Map? ?? {},
      );
      summaries[_optionKey(settings)] = result['summary'];

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

  /// Inserts a pending record for [url] then fetches/summarizes it via the
  /// backend's /process endpoint, mirroring electron/main.js's processLink.
  /// Broadcasts QueueEvents so pages showing the pending list can refresh
  /// even when this runs from the background (e.g. clipboard watcher).
  Future<int> processLink(
    String url,
    String backendUrl, {
    required PipelineSettings settings,
  }) async {
    final client = await SupabaseClientProvider.getClient();
    final inserted = await client
        .from('contents')
        .insert({
          'url': url,
          'tag': 'Article',
          'status': 'pending',
          'data': {'processing': true, 'stage': 'Fetching article...'},
        })
        .select('id')
        .single();
    final id = inserted['id'] as int;
    QueueEvents.notify();

    final data = <String, dynamic>{
      'processing': true,
      'stage': 'Fetching article...',
    };
    var tag = 'Article';
    Object? embedding;
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/process'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'url': url,
              'options': {
                'emoji': settings.emoji,
                'kidFriendly': settings.kidFriendly,
                'language': settings.language,
              },
              'categories': kDefaultCategories,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) {
        throw Exception('Backend process failed: ${res.reasonPhrase}');
      }
      final result = jsonDecode(res.body) as Map<String, dynamic>;

      if (result['success'] != true || result['text'] == null) {
        tag = 'Not Article';
      } else {
        data['original'] = result['text'];
        data['images'] = result['images'] ?? [];
        data['title'] = result['title'];
        data['summaries'] = <String, dynamic>{};
        data['embeddingError'] = result['embeddingError'];
        embedding = result['embedding'];
        if (result['error'] != null) {
          data['error'] = result['error'];
        } else {
          data['category'] = result['category'];
          (data['summaries'] as Map)[_optionKey(settings)] = result['summary'];
        }
      }
      data['processing'] = false;
      data.remove('stage');
      await client
          .from('contents')
          .update({'tag': tag, 'data': data, 'embedding': embedding})
          .eq('id', id);
    } catch (e) {
      data['processing'] = false;
      data.remove('stage');
      data['error'] = e.toString();
      await client
          .from('contents')
          .update({'tag': tag, 'data': data, 'embedding': embedding})
          .eq('id', id);
      rethrow;
    } finally {
      QueueEvents.notify();
    }
    return id;
  }
}
