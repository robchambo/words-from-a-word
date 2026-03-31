enum LanguageMode { russian, english }

extension LanguageModeExtension on LanguageMode {
  String get displayName {
    switch (this) {
      case LanguageMode.russian:
        return 'Русский';
      case LanguageMode.english:
        return 'English';
    }
  }

  String get flagEmoji {
    switch (this) {
      case LanguageMode.russian:
        return '🇷🇺';
      case LanguageMode.english:
        return '🇺🇸';
    }
  }

  String get levelsAsset {
    switch (this) {
      case LanguageMode.russian:
        return 'assets/data/russian_levels.json';
      case LanguageMode.english:
        return 'assets/data/english_levels.json';
    }
  }
}
