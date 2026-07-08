import 'package:shared_preferences/shared_preferences.dart';

/// Persists the Supabase auth session (access/refresh token) on-device.
/// Mirrors electron/db.js's authStorageAdapter, which stores the same
/// thing in settings.json instead.
class AuthSessionStore {
  static const _key = 'supabase_auth_session';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> save(String sessionJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, sessionJson);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
