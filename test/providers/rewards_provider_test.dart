import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/services/ad_gateway.dart';

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

  group('maybeRefillDailyHint', () {
    test('fills slot when never claimed and cap not reached', () async {
      final fakeNow = DateTime(2026, 4, 16, 9, 30);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 1);
      expect(provider.lastDailyClaimedOn, DateTime(2026, 4, 16));
    });

    test('does not double-fill on same day', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 1,
        'rewards.lastDailyClaimedOn': '2026-04-16',
      });
      final fakeNow = DateTime(2026, 4, 16, 22, 0);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 1);
    });

    test('fills on next day', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 0,
        'rewards.lastDailyClaimedOn': '2026-04-15',
      });
      final fakeNow = DateTime(2026, 4, 16, 0, 5);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 1);
      expect(provider.lastDailyClaimedOn, DateTime(2026, 4, 16));
    });

    test('respects free cap of 1', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 1,
        'rewards.lastDailyClaimedOn': '2026-04-15',
      });
      final fakeNow = DateTime(2026, 4, 16);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 1, reason: 'cap=1 for non-premium');
      expect(provider.lastDailyClaimedOn, DateTime(2026, 4, 16),
          reason: 'date is still stamped to prevent re-check within the day');
    });

    test('premium cap is 3', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 2,
        'rewards.premium': true,
        'rewards.lastDailyClaimedOn': '2026-04-15',
      });
      final fakeNow = DateTime(2026, 4, 16);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 3);
    });
  });

  group('consumeHint', () {
    test('returns freeSlot when slot > 0', () async {
      SharedPreferences.setMockInitialValues({'rewards.freeHintSlot': 1});
      final p = RewardsProvider();
      await p.load();

      final src = p.consumeHint();

      expect(src, HintSource.freeSlot);
      expect(p.freeHintSlot, 0);
    });

    test('returns purchased when slot empty and pool > 0', () async {
      SharedPreferences.setMockInitialValues({'rewards.purchasedHintCount': 2});
      final p = RewardsProvider();
      await p.load();

      final src = p.consumeHint();

      expect(src, HintSource.purchased);
      expect(p.purchasedHintCount, 1);
    });

    test('returns null when neither available', () async {
      final p = RewardsProvider();
      await p.load();

      expect(p.consumeHint(), isNull);
    });
  });

  test('addPurchasedHints increments pool', () async {
    final p = RewardsProvider();
    await p.load();

    p.addPurchasedHints(5);

    expect(p.purchasedHintCount, 5);
  });
}
