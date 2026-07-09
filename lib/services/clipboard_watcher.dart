import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_repository.dart';
import 'pipeline_settings_store.dart';
import 'supabase_config.dart';

final _urlRegex = RegExp(r'^https?://\S+$', caseSensitive: false);

/// Last clipboard text seen by either this watcher or the native
/// ClipboardAccessibilityService, so a link copied while backgrounded isn't
/// reprocessed a second time when the app is later resumed.
const _kLastSeenKey = 'clipboard_last_seen_text';

/// Watches the clipboard for article URLs, mirroring electron/main.js's
/// watchClipboard(). Android forbids background clipboard reads (API 29+)
/// for regular apps, so this foreground path only fires on app resume — the
/// closest mobile equivalent of the desktop app's window-focus listener.
/// ClipboardAccessibilityService (native) covers detection while backgrounded.
class ClipboardWatcher {
  final _repo = ContentRepository();

  /// Records the current clipboard contents without processing it, so the
  /// text already on the clipboard when the app starts isn't treated as a
  /// new link on the first resume.
  Future<void> primeBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kLastSeenKey) != null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    await prefs.setString(_kLastSeenKey, data?.text?.trim() ?? '');
  }

  Future<void> checkOnResume() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (text == prefs.getString(_kLastSeenKey)) return;
    await prefs.setString(_kLastSeenKey, text);
    if (!_urlRegex.hasMatch(text)) return;

    Fluttertoast.showToast(msg: 'Link detected - processing in background...');
    unawaited(_process(text));
  }

  Future<void> _process(String url) async {
    try {
      final backendUrl = (await SupabaseConfigStore.load()).cleanBackendUrl;
      final settings = await PipelineSettingsStore.load();
      await _repo.processLink(url, backendUrl, settings: settings);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Link processing failed: $e');
    }
  }
}
