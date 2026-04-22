// lib/services/achievement_engine.dart
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';

class AchievementEngine {
  final RewardsProvider _r;
  AchievementEngine(this._r);

  void onWordFound({
    required LanguageMode mode,
    required int wordLength,
    required bool isBonus,
    required bool isReplay,
  }) {
    if (isReplay) return;
    _r.unlockAchievement('first_word');
    if (isBonus) _r.unlockAchievement('first_bonus');
    _maybeCollector();
  }

  void onLevelComplete({
    required LanguageMode mode,
    required int levelId,
    required bool usedHint,
    required bool foundAllBonus,
    required bool isReplay,
  }) {
    if (isReplay) return;
    if (levelId == 1) _r.unlockAchievement('first_level');
    if (levelId == 10) _r.unlockAchievement('level_10');
    if (levelId == 25) _r.unlockAchievement('level_25');
    if (levelId == 50) _r.unlockAchievement('level_50');
    if (!usedHint) _r.unlockAchievement('no_hint_level');
    if (foundAllBonus) _r.unlockAchievement('perfect_level');
    // bilingual: check other language has highestCompletedLevel >= 1
    final other = mode == LanguageMode.russian
        ? LanguageMode.english
        : LanguageMode.russian;
    if ((_r.highestCompletedLevel[other] ?? 0) >= 1) {
      _r.unlockAchievement('bilingual');
    }
    _maybeCollector();
  }

  void onStreakIncrement(int newCount) {
    if (newCount >= 3) _r.unlockAchievement('streak_3');
    if (newCount >= 7) _r.unlockAchievement('streak_7');
    if (newCount >= 30) _r.unlockAchievement('streak_30');
    _maybeCollector();
  }

  void onFreeHintEarned() {
    _r.unlockAchievement('hint_free');
    _maybeCollector();
  }

  void _maybeCollector() {
    if (_r.achievementsUnlocked.length >= 10) {
      _r.unlockAchievement('collector');
    }
  }
}
