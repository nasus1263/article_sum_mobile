/// Static mirror of the desktop app's default pipeline settings
/// (electron/settingsStore.js DEFAULT_SETTINGS). Display-only on mobile —
/// none of this is persisted or wired to a backend.
class ProviderInfo {
  final String id;
  final String label;
  const ProviderInfo(this.id, this.label);
}

const kProviders = [
  ProviderInfo('claude', 'Claude'),
  ProviderInfo('gemini', 'Gemini'),
  ProviderInfo('openai', 'OpenAI'),
  ProviderInfo('nvidia', 'NVIDIA NIM'),
];

const kDefaultModels = {
  'claude': 'claude-haiku-4-5-20251001',
  'gemini': 'gemini-2.5-flash',
  'openai': 'gpt-5.1',
  'nvidia': 'meta/llama-3.3-70b-instruct',
};

class LanguageInfo {
  final String id;
  final String label;
  const LanguageInfo(this.id, this.label);
}

const kLanguages = [
  LanguageInfo('ko', 'Korean'),
  LanguageInfo('en', 'English'),
  LanguageInfo('ja', 'Japanese'),
  LanguageInfo('zh', 'Chinese'),
];

const kDefaultCategories = [
  'Politics',
  'Economy',
  'Society',
  'Culture',
  'Entertainment',
  'Sports',
  'IT',
];
