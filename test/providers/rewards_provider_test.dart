import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RewardsProvider initial state', () {
    test('defaults are correct on cold load', () async {
      final provider = RewardsProvider();
      await provider.load();

      expect(provider.schemaVersion, 1);
      expect(provider.freeHintSlot, 0);
      expect(provider.bonusWordCounter, 0);
      expect(provider.lastDailyClaimedOn, isNull);
      expect(provider.purchasedHintCount, 0);
      expect(provider.premium, isFalse);
      expect(provider.streakCount, 0);
      expect(provider.streakLastPlayedOn, isNull);
      expect(provider.achievementsUnlocked, isEmpty);
      expect(provider.currentLevel[LanguageMode.russian], 1);
      expect(provider.currentLevel[LanguageMode.english], 1);
      expect(provider.highestCompletedLevel[LanguageMode.russian], 0);
      expect(provider.highestCompletedLevel[LanguageMode.english], 0);
      expect(provider.levelBestScore[LanguageMode.russian], isEmpty);
      expect(provider.levelBestScore[LanguageMode.english], isEmpty);
      expect(provider.lifetimeScore[LanguageMode.russian], 0);
      expect(provider.lifetimeScore[LanguageMode.english], 0);
    });
  });

  group('RewardsProvider persistence round-trip', () {
    test('saves and reloads all fields', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.schemaVersion': 1,
        'rewards.freeHintSlot': 1,
        'rewards.bonusWordCounter': 7,
        'rewards.lastDailyClaimedOn': '2026-04-15',
        'rewards.purchasedHintCount': 3,
        'rewards.premium': true,
        'rewards.streakCount': 4,
        'rewards.streakLastPlayedOn': '2026-04-15',
        'rewards.achievementsUnlocked': '["first_word","first_level"]',
        'rewards.currentLevel.ru': 12,
        'rewards.currentLevel.en': 8,
        'rewards.highestCompletedLevel.ru': 11,
        'rewards.highestCompletedLevel.en': 7,
        'rewards.levelBestScore.ru': '{"1":120,"2":90}',
        'rewards.levelBestScore.en': '{"1":80}',
        'rewards.lifetimeScore.ru': 1500,
        'rewards.lifetimeScore.en': 800,
      });

      final provider = RewardsProvider();
      await provider.load();

      expect(provider.freeHintSlot, 1);
      expect(provider.bonusWordCounter, 7);
      expect(provider.lastDailyClaimedOn, DateTime(2026, 4, 15));
      expect(provider.purchasedHintCount, 3);
      expect(provider.premium, isTrue);
      expect(provider.streakCount, 4);
      expect(provider.streakLastPlayedOn, DateTime(2026, 4, 15));
      expect(provider.achievementsUnlocked, {'first_word', 'first_level'});
      expect(provider.currentLevel[LanguageMode.russian], 12);
      expect(provider.currentLevel[LanguageMode.english], 8);
      expect(provider.highestCompletedLevel[LanguageMode.russian], 11);
      expect(provider.highestCompletedLevel[LanguageMode.english], 7);
      expect(provider.levelBestScore[LanguageMode.russian]![1], 120);
      expect(provider.levelBestScore[LanguageMode.russian]![2], 90);
      expect(provider.levelBestScore[LanguageMode.english]![1], 80);
      expect(provider.lifetimeScore[LanguageMode.russian], 1500);
      expect(provider.lifetimeScore[LanguageMode.english], 800);
    });
  });

  group('RewardsProvider migration from v1.0', () {
    test('bare SharedPreferences (only languageMode) produces defaults', () async {
      SharedPreferences.setMockInitialValues({
        'settings.languageMode': 'russian',
      });

      final provider = RewardsProvider();
      await provider.load();

      expect(provider.schemaVersion, 1);
      expect(provider.freeHintSlot, 0);
      expect(provider.currentLevel[LanguageMode.russian], 1);
    });
  });
}
