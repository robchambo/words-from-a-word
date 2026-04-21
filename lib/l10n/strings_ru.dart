import '../models/game_state.dart';

class StringsRu {
  // Home screen
  static const String appTitle = 'Слова из Слова';
  static const String appSubtitle = 'Классическая игра';
  static const String dictionaryLabel = 'Русский словарь';
  static const String playButton = 'Играть';
  static const String rulesButton = 'Правила';
  static const String settingsButton = 'Настройки';
  static const String leaderboardButton = 'Рейтинг';
  static const String footerText = 'Слова из Слова · Русский язык';

  // Language select
  static const String chooseLang = 'Выберите язык';
  static const String playRussian = 'Русский';
  static const String playEnglish = 'English';
  static const String langToggleHint = 'Сменить язык';

  // Game screen
  static const String subtitle = 'Составьте слова из этих букв';
  static const String hintButton = 'Подсказка';
  static const String checkButton = 'Проверить';
  static const String levelLabel = 'УР.';
  static const String scoreLabel = 'Очки';
  static const String wordsLeft = 'слов осталось';
  static const String wordsOf = 'слов';
  static const String startPrompt = 'Начинайте!';
  static const String allFoundPrompt = 'Отлично!';
  static const String selectLetters = 'Выберите буквы';
  static const String bonusLabel = 'Бонус';
  static const String tooCommonWord = 'Слово слишком распространено!';
  static const String bonusCounterLabel = 'Бонусных слов';
  static const String bankedHintsLabel = 'Подсказок';

  static String lettersHeader(int n) {
    if (n == 1) return '1 БУКВА';
    if (n >= 2 && n <= 4) return '$n БУКВЫ';
    return '$n БУКВ';
  }

  static String difficultyLabel(LevelDifficulty d) {
    switch (d) {
      case LevelDifficulty.beginner:
        return 'НАЧИНАЮЩИЙ';
      case LevelDifficulty.easy:
        return 'ЛЁГКИЙ';
      case LevelDifficulty.medium:
        return 'СРЕДНИЙ';
      case LevelDifficulty.hard:
        return 'СЛОЖНЫЙ';
      case LevelDifficulty.expert:
        return 'ЭКСПЕРТ';
    }
  }

  // Rules modal
  static const String rulesTitle = 'Правила игры';
  static const String rulesGoal =
      'Цель: составьте как можно больше слов из букв одного длинного слова.';
  static const String rulesHow =
      'Как играть: нажимайте на буквы внизу экрана, чтобы составить слово. Затем нажмите «Проверить».';
  static const String rulesRules =
      'Правила: минимум 3 буквы. Каждую букву можно использовать только столько раз, сколько она встречается в исходном слове.';
  static const String rulesHint =
      'Подсказка: нажмите на лампочку, чтобы получить первую букву следующего слова. Доступно 3 подсказки на уровень.';
  static const String rulesScore =
      'Очки: каждая буква = 10 очков. Длинные слова дают бонус!';
  static const String rulesComplete =
      'Уровень пройден, когда найдены все обязательные слова. Бонусные слова — приятный сюрприз!';
  static const String rulesClose = 'Понятно, играть!';

  // Level complete
  static const String levelCompleteTitle = 'Уровень пройден!';
  static const String nextLevelButton = 'Следующий уровень';
  static const String wordsFoundLabel = 'слов найдено';

  // Settings screen
  static const String settingsTitle = 'Настройки';
  static const String settingsLanguage = 'Язык';
  static const String settingsRules = 'Как играть';
  static const String settingsMute = 'Выключить звук';
  static const String settingsRemoveAds = 'Убрать рекламу';
  static const String settingsRestore = 'Восстановить покупки';
  static const String settingsPrivacy = 'Политика конфиденциальности';
}
