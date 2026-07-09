import 'package:shared_preferences/shared_preferences.dart';

import '../constants/pipeline_defaults.dart';

/// Mirrors the desktop app's settingsStore.json defaultOptions/folders.
/// Category (LLM-assigned, from kDefaultCategories) is fixed and not stored
/// here; folders are user-defined groupings used when approving items.
class PipelineSettings {
  final bool emoji;
  final bool kidFriendly;
  final String language;
  final List<String> folders;

  const PipelineSettings({
    this.emoji = true,
    this.kidFriendly = false,
    this.language = 'ko',
    this.folders = kDefaultFolders,
  });

  PipelineSettings copyWith({
    bool? emoji,
    bool? kidFriendly,
    String? language,
    List<String>? folders,
  }) => PipelineSettings(
    emoji: emoji ?? this.emoji,
    kidFriendly: kidFriendly ?? this.kidFriendly,
    language: language ?? this.language,
    folders: folders ?? this.folders,
  );
}

/// Persists pipeline defaults (emoji/kid-friendly/language/folders) used
/// by processLink and regenerate, so both draw from the same Settings state.
class PipelineSettingsStore {
  static const _emojiKey = 'pipeline_emoji';
  static const _kidFriendlyKey = 'pipeline_kid_friendly';
  static const _languageKey = 'pipeline_language';
  static const _foldersKey = 'pipeline_folders';

  static Future<PipelineSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PipelineSettings(
      emoji: prefs.getBool(_emojiKey) ?? true,
      kidFriendly: prefs.getBool(_kidFriendlyKey) ?? false,
      language: prefs.getString(_languageKey) ?? 'ko',
      folders: prefs.getStringList(_foldersKey) ?? List.of(kDefaultFolders),
    );
  }

  static Future<void> save(PipelineSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emojiKey, settings.emoji);
    await prefs.setBool(_kidFriendlyKey, settings.kidFriendly);
    await prefs.setString(_languageKey, settings.language);
    await prefs.setStringList(_foldersKey, settings.folders);
  }
}
