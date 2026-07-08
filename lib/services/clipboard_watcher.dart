import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'content_repository.dart';
import 'pipeline_settings_store.dart';
import 'supabase_config.dart';

final _urlRegex = RegExp(r'^https?://\S+$', caseSensitive: false);

/// Watches the clipboard for article URLs, mirroring electron/main.js's
/// watchClipboard(). Android forbids background clipboard reads (API 29+),
/// so callers should invoke [checkOnResume] only when the app regains
/// foreground focus — the closest mobile equivalent of the desktop app's
/// window-focus listener.
class ClipboardWatcher {
  final _repo = ContentRepository();
  String? _lastText;
  bool _baselined = false;

  /// Records the current clipboard contents without processing it, so the
  /// text already on the clipboard when the app starts isn't treated as a
  /// new link on the first resume.
  Future<void> primeBaseline() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    _lastText = data?.text?.trim();
    _baselined = true;
  }

  Future<void> checkOnResume() async {
    if (!_baselined) {
      await primeBaseline();
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || text == _lastText) return;
    _lastText = text;
    if (!_urlRegex.hasMatch(text)) return;

    Fluttertoast.showToast(msg: '링크 감지됨 — 백그라운드에서 처리 중...');
    unawaited(_process(text));
  }

  Future<void> _process(String url) async {
    try {
      final backendUrl = (await SupabaseConfigStore.load()).cleanBackendUrl;
      final settings = await PipelineSettingsStore.load();
      await _repo.processLink(url, backendUrl, settings: settings);
    } catch (e) {
      Fluttertoast.showToast(msg: '링크 처리 실패: $e');
    }
  }
}
