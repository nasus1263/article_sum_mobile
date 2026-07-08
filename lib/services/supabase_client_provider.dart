import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_session_store.dart';
import 'supabase_config.dart';

/// Single shared SupabaseClient for the whole app. Auth state (the signed
/// in session) lives on the GoTrueClient instance, so every query that
/// needs RLS to see "who's logged in" — content reads and auth calls alike
/// — must share this one client rather than each creating its own.
class SupabaseClientProvider {
  static SupabaseClient? _client;
  static String? _clientKey;
  static Future<void>? _restoring;

  static Future<SupabaseClient> getClient() async {
    final config = await SupabaseConfigStore.load();
    if (!config.isConfigured) {
      throw Exception(
        'Supabase is not configured. Set the project URL and anon key in Settings.',
      );
    }
    final key = '${config.url}|${config.anonKey}';
    if (_client == null || _clientKey != key) {
      final client = SupabaseClient(config.url, config.anonKey);
      _client = client;
      _clientKey = key;
      _restoring = _restoreSession(client);
      client.auth.onAuthStateChange.listen((state) {
        final session = state.session;
        if (session != null) {
          AuthSessionStore.save(jsonEncode(session.toJson()));
        } else {
          AuthSessionStore.clear();
        }
      });
    }
    await _restoring;
    return _client!;
  }

  static Future<void> _restoreSession(SupabaseClient client) async {
    final stored = await AuthSessionStore.load();
    if (stored == null) return;
    try {
      await client.auth.recoverSession(stored);
    } catch (_) {
      await AuthSessionStore.clear();
    }
  }
}
