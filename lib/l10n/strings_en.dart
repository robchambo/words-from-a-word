import '../models/game_state.dart';

class StringsEn {
  // Home screen
  static const String appTitle = 'Words from a Word';
  static const String appSubtitle = 'Classic Word Game';
  static const String dictionaryLabel = 'English Dictionary';
  static const String playButton = 'Play';
  static const String rulesButton = 'Rules';
  static const String settingsButton = 'Settings';
  static const String leaderboardButton = 'Leaderboard';
  static const String footerText = 'Words from a Word · English';

  // Language select
  static const String chooseLang = 'Choose Language';
  static const String playRussian = 'Russian';
  static const String playEnglish = 'English (American)';
  static const String langToggleHint = 'Switch language';

  // Game screen
  static const String subtitle = 'Make words from these letters';
  static const String hintButton = 'Hint';
  static const String checkButton = 'Check';
  static const String levelLabel = 'LVL';
  static const String scoreLabel = 'Score';
  static const String wordsLeft = 'words left';
  static const String wordsOf = 'words';
  static const String startPrompt = 'Start playing!';
  static const String allFoundPrompt = 'Excellent!';
  static const String selectLetters = 'Select letters';
  static const String bonusLabel = 'Bonus';
  static const String tooCommonWord = 'Word is too common!';
  static const String bonusCounterLabel = 'Bonus words';
  static const String bankedHintsLabel = 'Hints';

  static String difficultyLabel(LevelDifficulty d) {
    switch (d) {
      case LevelDifficulty.beginner:
        return 'BEGINNER';
      case LevelDifficulty.easy:
        return 'EASY';
      case LevelDifficulty.medium:
        return 'MEDIUM';
      case LevelDifficulty.hard:
        return 'HARD';
      case LevelDifficulty.expert:
        return 'EXPERT';
    }
  }

  static String lettersHeader(int n) => '$n LETTERS';

  // Rules modal
  static const String rulesTitle = 'How to Play';
  static const String rulesGoal =
      'Goal: form as many words as possible from the letters of one long source word.';
  static const String rulesHow =
      'How to play: tap the letter tiles at the bottom to build a word, then tap Check.';
  static const String rulesRules =
      'Rules: minimum 3 letters. Each letter can only be used as many times as it appears in the source word.';
  static const String rulesHint =
      'Hint: tap the lightbulb to reveal the first letter of the next unsolved word. 3 hints per level.';
  static const String rulesScore =
      'Scoring: 10 points per letter. Longer words earn a bonus!';
  static const String rulesComplete =
      'Level complete when all required words are found. Bonus words are a nice surprise!';
  static const String rulesClose = 'Got it, let\'s play!';

  // Level complete
  static const String levelCompleteTitle = 'Level Complete!';
  static const String nextLevelButton = 'Next Level';
  static const String wordsFoundLabel = 'words found';

  // Settings screen
  static const String settingsTitle = 'Settings';
  static const String settingsLanguage = 'Language';
  static const String settingsRules = 'How to play';
  static const String settingsMute = 'Mute sounds';
  static const String settingsRemoveAds = 'Remove ads';
  static const String settingsRestore = 'Restore purchases';
  static const String settingsPrivacy = 'Privacy policy';
}
