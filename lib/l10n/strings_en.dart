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
      'Hints: tap the lightbulb to reveal one safe letter in an unsolved word — never the last one. Earn free hints by finding 10 bonus words, or watch a short ad.';
  static const String rulesScore =
      'Scoring: 10 points per letter, with length bonuses for 4+ letter words. Bonus words give a flat 15 points. Your score banks when the level is complete — abandon mid-level and it is lost.';
  static const String rulesComplete =
      'Level complete when all required words are found. Bonus words are a nice surprise!';
  static const String freeHintEarnedTitle = 'Free hint earned!';
  static const String freeHintEarnedBody = '10 bonus words — one hint is yours.';
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

  // Progression
  static const String homePlay = 'Play';
  static const String homeLevels = 'Levels';
  static const String homeTrophies = 'Trophies';
  static const String homeSettings = 'Settings';
  static const String lifetimeScoreLabel = 'Lifetime score';
  static const String streakDaysLabel = 'Day streak';

  static const String levelPickerTitle = 'Levels';
  static const String levelPickerLocked = 'Locked';
  static const String levelPickerBestScore = 'Best';

  static const String trophiesTitle = 'Trophies';
  static const String trophiesLocked = 'Locked';
  static const String trophiesUnlocked = 'Unlocked';

  static const String libraryCompleteTitle = 'Library complete!';
  static const String libraryCompleteBody =
      'You have cleared every level. More are on the way. Replay any level for fun — scores do not update in replay.';
  static const String libraryCompleteReplay = 'Replay levels';
  static const String libraryCompleteClose = 'Close';

  static const String replayModeBanner = 'Replay mode — scores not recorded';
  static const String newBestTag = 'NEW BEST';
}
