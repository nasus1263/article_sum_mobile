/// Static mirror of the desktop app's default pipeline settings.
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
