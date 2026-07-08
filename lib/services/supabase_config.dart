import 'package:shared_preferences/shared_preferences.dart';

const _kDefaultUrl = 'https://wjzdjvyefjtivtayayfc.supabase.co/';
const _kDefaultAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqemRqdnllZmp0aXZ0YXlheWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1MTE0OTYsImV4cCI6MjA5OTA4NzQ5Nn0.MxIpIu7kCJn__MF_ciyLpCbSQ0dIeMf8sgfuVhSYfl0';

/// Default backend URL shown/used before the user configures one in Settings.
const kDefaultBackendUrl = 'http://127.0.0.1:3000';

class SupabaseConfig {
  final String url;
  final String anonKey;
  final String backendUrl;

  const SupabaseConfig({
    this.url = _kDefaultUrl,
    this.anonKey = _kDefaultAnonKey,
    this.backendUrl = kDefaultBackendUrl,
  });

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  String get cleanBackendUrl => backendUrl.replaceAll(RegExp(r'/+$'), '');

  SupabaseConfig copyWith({String? url, String? anonKey, String? backendUrl}) =>
      SupabaseConfig(
        url: url ?? this.url,
        anonKey: anonKey ?? this.anonKey,
        backendUrl: backendUrl ?? this.backendUrl,
      );
}

/// Persists the Supabase project URL / anon key / backend URL.
class SupabaseConfigStore {
  static const _urlKey = 'supabase_url';
  static const _anonKeyKey = 'supabase_anon_key';
  static const _backendUrlKey = 'backend_url';

  static Future<SupabaseConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SupabaseConfig(
      url: prefs.getString(_urlKey) ?? _kDefaultUrl,
      anonKey: prefs.getString(_anonKeyKey) ?? _kDefaultAnonKey,
      backendUrl: prefs.getString(_backendUrlKey) ?? kDefaultBackendUrl,
    );
  }

  static Future<void> save(SupabaseConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, config.url);
    await prefs.setString(_anonKeyKey, config.anonKey);
    await prefs.setString(_backendUrlKey, config.backendUrl);
  }
}
