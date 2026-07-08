import 'package:shared_preferences/shared_preferences.dart';

import '../constants/pipeline_defaults.dart';

/// Mirrors the desktop app's settingsStore.json defaultOptions/categories.
class PipelineSettings {
  final bool emoji;
  final bool kidFriendly;
  final String language;
  final List<String> categories;

  const PipelineSettings({
    this.emoji = true,
    this.kidFriendly = false,
    this.language = 'ko',
    this.categories = kDefaultCategories,
  });

  PipelineSettings copyWith({
    bool? emoji,
    bool? kidFriendly,
    String? language,
    List<String>? categories,
  }) => PipelineSettings(
    emoji: emoji ?? this.emoji,
    kidFriendly: kidFriendly ?? this.kidFriendly,
    language: language ?? this.language,
    categories: categories ?? this.categories,
  );
}

/// Persists pipeline defaults (emoji/kid-friendly/language/categories) used
/// by processLink and regenerate, so both draw from the same Settings state.
class PipelineSettingsStore {
  static const _emojiKey = 'pipeline_emoji';
  static const _kidFriendlyKey = 'pipeline_kid_friendly';
  static const _languageKey = 'pipeline_language';
  static const _categoriesKey = 'pipeline_categories';

  static Future<PipelineSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PipelineSettings(
      emoji: prefs.getBool(_emojiKey) ?? true,
      kidFriendly: prefs.getBool(_kidFriendlyKey) ?? false,
      language: prefs.getString(_languageKey) ?? 'ko',
      categories:
          prefs.getStringList(_categoriesKey) ?? List.of(kDefaultCategories),
    );
  }

  static Future<void> save(PipelineSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emojiKey, settings.emoji);
    await prefs.setBool(_kidFriendlyKey, settings.kidFriendly);
    await prefs.setString(_languageKey, settings.language);
    await prefs.setStringList(_categoriesKey, settings.categories);
  }
}
