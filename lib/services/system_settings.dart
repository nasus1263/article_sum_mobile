import 'package:flutter/services.dart';

/// Bridges to MainActivity.kt for opening native Android settings screens
/// that Flutter has no direct API for.
class SystemSettings {
  static const _channel = MethodChannel('com.example.article_sum_mobile/settings');

  static Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');
}
