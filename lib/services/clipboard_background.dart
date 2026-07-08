import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'content_repository.dart';
import 'pipeline_settings_store.dart';
import 'supabase_config.dart';

/// Must match ClipboardAccessibilityService.CHANNEL on the Kotlin side.
const _kChannelName = 'com.example.article_sum_mobile/clipboard_bg';

/// Entry point for the headless FlutterEngine that ClipboardAccessibilityService
/// spins up when it detects a URL on the clipboard while the app has no UI
/// running. Runs processLink using the same Dart networking/Supabase code the
/// foreground ClipboardWatcher uses, then tears itself down.
@pragma('vm:entry-point')
void clipboardCallbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(_kChannelName);
  channel.setMethodCallHandler((call) async {
    if (call.method != 'processLink') return;
    final url = call.arguments as String;
    try {
      final backendUrl = (await SupabaseConfigStore.load()).cleanBackendUrl;
      final settings = await PipelineSettingsStore.load();
      await ContentRepository().processLink(url, backendUrl, settings: settings);
    } catch (e) {
      await channel.invokeMethod('error', e.toString());
    } finally {
      await channel.invokeMethod('done');
    }
  });
  channel.invokeMethod('ready');
}
