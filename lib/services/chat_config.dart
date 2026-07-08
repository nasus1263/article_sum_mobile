import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/pipeline_defaults.dart';

/// Persists the per-provider API keys and model names used for Chat.
/// Mirrors the desktop app's useApiKeys/useModels localStorage hooks.
class ChatConfigStore {
  static const _apiKeysKey = 'chat_api_keys';
  static const _modelsKey = 'chat_models';

  static Future<Map<String, String>> loadApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_apiKeysKey);
    final stored = raw != null ? (jsonDecode(raw) as Map).cast<String, dynamic>() : <String, dynamic>{};
    return {for (final p in kProviders) p.id: (stored[p.id] as String?) ?? ''};
  }

  static Future<void> saveApiKeys(Map<String, String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeysKey, jsonEncode(keys));
  }

  static Future<Map<String, String>> loadModels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_modelsKey);
    final stored = raw != null ? (jsonDecode(raw) as Map).cast<String, dynamic>() : <String, dynamic>{};
    return {
      for (final p in kProviders) p.id: (stored[p.id] as String?) ?? kDefaultModels[p.id]!,
    };
  }

  static Future<void> saveModels(Map<String, String> models) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelsKey, jsonEncode(models));
  }
}
