// test/services/achievement_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/services/achievement_engine.dart';

Future<RewardsProvider> _makeRewards() async {
  SharedPreferences.setMockInitialValues({});
  final rewards = RewardsProvider();
  await rewards.load();
  return rewards;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('first_word', () {
    test('unlocks on first word found (non-replay)', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onWordFound(
        mode: LanguageMode.english,
        wordLength: 4,
        isBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('first_word'), true);
    });

    test('does NOT unlock in replay mode', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onWordFound(
        mode: LanguageMode.english,
        wordLength: 4,
        isBonus: false,
        isReplay: true,
      );
      expect(rewards.achievementsUnlocked.contains('first_word'), false);
    });
  });

  group('first_bonus', () {
    test('unlocks on first bonus word found', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onWordFound(
        mode: LanguageMode.english,
        wordLength: 4,
        isBonus: true,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('first_bonus'), true);
    });

    test('does NOT unlock when isBonus=false', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onWordFound(
        mode: LanguageMode.english,
        wordLength: 4,
        isBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('first_bonus'), false);
    });
  });

  group('first_level', () {
    test('unlocks on onLevelComplete with levelId=1', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 1,
        usedHint: true,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('first_level'), true);
    });

    test('does NOT unlock in replay mode', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 1,
        usedHint: true,
        foundAllBonus: false,
        isReplay: true,
      );
      expect(rewards.achievementsUnlocked.contains('first_level'), false);
    });
  });

  group('level milestones', () {
    test('level_10 unlocks on levelId=10', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 10,
        usedHint: true,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('level_10'), true);
    });

    test('level_25 unlocks on levelId=25', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 25,
        usedHint: true,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('level_25'), true);
    });

    test('level_50 unlocks on levelId=50', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 50,
        usedHint: true,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('level_50'), true);
    });

    test('level_10 does NOT unlock on levelId=9', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 9,
        usedHint: true,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('level_10'), false);
    });
  });

  group('streaks', () {
    test('streak_3 unlocks on onStreakIncrement(3)', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onStreakIncrement(3);
      expect(rewards.achievementsUnlocked.contains('streak_3'), true);
    });

    test('streak_7 unlocks on onStreakIncrement(7)', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onStreakIncrement(7);
      expect(rewards.achievementsUnlocked.contains('streak_7'), true);
    });

    test('streak_30 unlocks on onStreakIncrement(30)', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onStreakIncrement(30);
      expect(rewards.achievementsUnlocked.contains('streak_30'), true);
    });

    test('streak_7 also unlocks streak_3 (cumulative thresholds)', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onStreakIncrement(7);
      expect(rewards.achievementsUnlocked.contains('streak_3'), true);
      expect(rewards.achievementsUnlocked.contains('streak_7'), true);
    });

    test('streak_3 does NOT unlock on count=2', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onStreakIncrement(2);
      expect(rewards.achievementsUnlocked.contains('streak_3'), false);
    });
  });

  group('hint_free', () {
    test('unlocks on onFreeHintEarned', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onFreeHintEarned();
      expect(rewards.achievementsUnlocked.contains('hint_free'), true);
    });
  });

  group('no_hint_level', () {
    test('unlocks on onLevelComplete with usedHint=false', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 2,
        usedHint: false,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('no_hint_level'), true);
    });

    test('does NOT unlock when usedHint=true', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 2,
        usedHint: true,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('no_hint_level'), false);
    });
  });

  group('perfect_level', () {
    test('unlocks on onLevelComplete with foundAllBonus=true', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 2,
        usedHint: true,
        foundAllBonus: true,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('perfect_level'), true);
    });

    test('does NOT unlock when foundAllBonus=false', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 2,
        usedHint: true,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('perfect_level'), false);
    });
  });

  group('bilingual', () {
    test('unlocks when other language has highestCompletedLevel >= 1', () async {
      final rewards = await _makeRewards();
      // Simulate English already completed at least level 1
      rewards.highestCompletedLevel[LanguageMode.english] = 1;
      final engine = AchievementEngine(rewards);
      // Now complete a Russian level
      engine.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 2,
        usedHint: true,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('bilingual'), true);
    });

    test('does NOT unlock when other language has highestCompletedLevel=0', () async {
      final rewards = await _makeRewards();
      // English has not completed any level (default 0)
      final engine = AchievementEngine(rewards);
      engine.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 2,
        usedHint: true,
        foundAllBonus: false,
        isReplay: false,
      );
      expect(rewards.achievementsUnlocked.contains('bilingual'), false);
    });
  });

  group('collector', () {
    test('unlocks when 10 or more achievements are earned', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);

      // Fire events that unlock multiple achievements:
      // first_word (1)
      engine.onWordFound(
        mode: LanguageMode.english, wordLength: 4, isBonus: false, isReplay: false);
      // first_bonus (2)
      engine.onWordFound(
        mode: LanguageMode.english, wordLength: 4, isBonus: true, isReplay: false);
      // first_level (3), no_hint_level (4)
      engine.onLevelComplete(
        mode: LanguageMode.english, levelId: 1, usedHint: false,
        foundAllBonus: false, isReplay: false);
      // perfect_level (5)
      engine.onLevelComplete(
        mode: LanguageMode.english, levelId: 2, usedHint: true,
        foundAllBonus: true, isReplay: false);
      // hint_free (6)
      engine.onFreeHintEarned();
      // streak_3 (7), streak_7 (8), streak_30 (9)
      engine.onStreakIncrement(30);
      // level_10 (10) — collector should fire after this one
      engine.onLevelComplete(
        mode: LanguageMode.english, levelId: 10, usedHint: true,
        foundAllBonus: false, isReplay: false);

      expect(rewards.achievementsUnlocked.contains('collector'), true);
    });

    test('does NOT unlock with fewer than 10 achievements', () async {
      final rewards = await _makeRewards();
      final engine = AchievementEngine(rewards);

      // Only fire 3 unique achievements
      engine.onWordFound(
        mode: LanguageMode.english, wordLength: 4, isBonus: false, isReplay: false);
      engine.onWordFound(
        mode: LanguageMode.english, wordLength: 4, isBonus: true, isReplay: false);
      engine.onFreeHintEarned();

      expect(rewards.achievementsUnlocked.contains('collector'), false);
    });
  });
}
