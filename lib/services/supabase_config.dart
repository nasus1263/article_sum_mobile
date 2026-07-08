import 'package:shared_preferences/shared_preferences.dart';

const _kDefaultUrl = 'https://wjzdjvyefjtivtayayfc.supabase.co/';
const _kDefaultAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqemRqdnllZmp0aXZ0YXlheWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1MTE0OTYsImV4cCI6MjA5OTA4NzQ5Nn0.MxIpIu7kCJn__MF_ciyLpCbSQ0dIeMf8sgfuVhSYfl0';

class SupabaseConfig {
  final String url;
  final String anonKey;

  const SupabaseConfig({this.url = _kDefaultUrl, this.anonKey = _kDefaultAnonKey});

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  SupabaseConfig copyWith({String? url, String? anonKey}) =>
      SupabaseConfig(url: url ?? this.url, anonKey: anonKey ?? this.anonKey);
}

/// Persists the Supabase project URL / anon key entered in Settings.
/// Mirrors electron/settingsStore.js's `supabase` field, minus the rest
/// of the pipeline settings (those aren't implemented on mobile).
class SupabaseConfigStore {
  static const _urlKey = 'supabase_url';
  static const _anonKeyKey = 'supabase_anon_key';

  static Future<SupabaseConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SupabaseConfig(
      url: prefs.getString(_urlKey) ?? _kDefaultUrl,
      anonKey: prefs.getString(_anonKeyKey) ?? _kDefaultAnonKey,
    );
  }

  static Future<void> save(SupabaseConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, config.url);
    await prefs.setString(_anonKeyKey, config.anonKey);
  }
}
