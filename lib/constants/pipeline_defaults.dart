/// Static mirror of the desktop app's default pipeline settings.
/// Claude is the only supported provider after the cleanup.
class ProviderInfo {
  final String id;
  final String label;
  const ProviderInfo(this.id, this.label);
}

const kProviders = [
  ProviderInfo('claude', 'Claude'),
];

const kDefaultModels = {
  'claude': 'claude-haiku-4-5-20251001',
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
