// lib/data/achievements.dart
import '../models/language_mode.dart';

class Achievement {
  final String id;
  final String Function(LanguageMode) title;
  final String Function(LanguageMode) description;
  const Achievement(this.id, this.title, this.description);
}

String _t(LanguageMode m, String ru, String en) =>
    m == LanguageMode.russian ? ru : en;

const kAchievements = <Achievement>[
  Achievement('first_word',
    _firstWordTitle, _firstWordDesc),
  Achievement('first_bonus',
    _firstBonusTitle, _firstBonusDesc),
  Achievement('first_level',
    _firstLevelTitle, _firstLevelDesc),
  Achievement('level_10', _lvl10Title, _lvl10Desc),
  Achievement('level_25', _lvl25Title, _lvl25Desc),
  Achievement('level_50', _lvl50Title, _lvl50Desc),
  Achievement('streak_3', _s3Title, _s3Desc),
  Achievement('streak_7', _s7Title, _s7Desc),
  Achievement('streak_30', _s30Title, _s30Desc),
  Achievement('hint_free', _hintFreeTitle, _hintFreeDesc),
  Achievement('no_hint_level', _noHintTitle, _noHintDesc),
  Achievement('perfect_level', _perfectTitle, _perfectDesc),
  Achievement('bilingual', _biTitle, _biDesc),
  Achievement('collector', _colTitle, _colDesc),
];

String _firstWordTitle(LanguageMode m) => _t(m, 'Первое слово', 'First word');
String _firstWordDesc(LanguageMode m) => _t(m, 'Найдено первое слово.', 'Found your first word.');
String _firstBonusTitle(LanguageMode m) => _t(m, 'Бонус!', 'Bonus!');
String _firstBonusDesc(LanguageMode m) => _t(m, 'Найдено первое бонусное слово.', 'Found your first bonus word.');
String _firstLevelTitle(LanguageMode m) => _t(m, 'Первый уровень', 'First level');
String _firstLevelDesc(LanguageMode m) => _t(m, 'Пройден уровень 1.', 'Completed level 1.');
String _lvl10Title(LanguageMode m) => _t(m, 'Десятка', 'Level 10');
String _lvl10Desc(LanguageMode m) => _t(m, 'Пройден уровень 10.', 'Completed level 10.');
String _lvl25Title(LanguageMode m) => _t(m, 'Четверть сотни', 'Level 25');
String _lvl25Desc(LanguageMode m) => _t(m, 'Пройден уровень 25.', 'Completed level 25.');
String _lvl50Title(LanguageMode m) => _t(m, 'Полсотни', 'Level 50');
String _lvl50Desc(LanguageMode m) => _t(m, 'Пройден уровень 50.', 'Completed level 50.');
String _s3Title(LanguageMode m) => _t(m, 'Три дня подряд', '3-day streak');
String _s3Desc(LanguageMode m) => _t(m, 'Играли три дня подряд.', 'Three days in a row.');
String _s7Title(LanguageMode m) => _t(m, 'Неделя', '7-day streak');
String _s7Desc(LanguageMode m) => _t(m, 'Играли неделю подряд.', 'Seven days in a row.');
String _s30Title(LanguageMode m) => _t(m, 'Месяц', '30-day streak');
String _s30Desc(LanguageMode m) => _t(m, 'Играли месяц подряд.', 'Thirty days in a row.');
String _hintFreeTitle(LanguageMode m) => _t(m, 'Халявная подсказка', 'Free hint earned');
String _hintFreeDesc(LanguageMode m) => _t(m, 'Заработана бесплатная подсказка из 10 бонусов.', 'Earned a free hint from bonus words.');
String _noHintTitle(LanguageMode m) => _t(m, 'Без подсказок', 'No hint');
String _noHintDesc(LanguageMode m) => _t(m, 'Уровень пройден без подсказок.', 'Completed a level without hints.');
String _perfectTitle(LanguageMode m) => _t(m, 'Идеальный уровень', 'Perfect level');
String _perfectDesc(LanguageMode m) => _t(m, 'Найдены все бонусные слова.', 'Found every bonus word in a level.');
String _biTitle(LanguageMode m) => _t(m, 'Билингва', 'Bilingual');
String _biDesc(LanguageMode m) => _t(m, 'Пройден уровень в обоих языках.', 'Completed a level in both languages.');
String _colTitle(LanguageMode m) => _t(m, 'Коллекционер', 'Collector');
String _colDesc(LanguageMode m) => _t(m, 'Открыто 10 наград.', 'Unlocked 10 achievements.');
