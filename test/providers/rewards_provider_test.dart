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
        'language_mode': 'russian',
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

  group('incrementBonusCounter', () {
    test('increments up to 10', () async {
      final p = RewardsProvider();
      await p.load();

      for (var i = 0; i < 9; i++) {
        p.incrementBonusCounter();
      }
      expect(p.bonusWordCounter, 9);
      expect(p.freeHintSlot, 0);

      p.incrementBonusCounter();

      expect(p.bonusWordCounter, 0, reason: 'resets after threshold');
      expect(p.freeHintSlot, 1, reason: 'earned one hint');
    });

    test('freezes at 10 if slot already full', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 1,
        'rewards.bonusWordCounter': 9,
      });
      final p = RewardsProvider();
      await p.load();

      p.incrementBonusCounter();

      expect(p.bonusWordCounter, 10, reason: 'frozen at threshold');
      expect(p.freeHintSlot, 1);

      p.incrementBonusCounter();

      expect(p.bonusWordCounter, 10);
    });
  });

  test('markPremium raises slot cap', () async {
    SharedPreferences.setMockInitialValues({
      'rewards.freeHintSlot': 1,
      'rewards.lastDailyClaimedOn': '2026-04-15',
    });
    final fakeNow = DateTime(2026, 4, 16);
    final p = RewardsProvider(clock: () => fakeNow);
    await p.load();

    p.markPremium();
    p.maybeRefillDailyHint();

    expect(p.premium, isTrue);
    expect(p.freeHintSlot, 2,
        reason: 'cap is now 3; today\'s refill can bump 1->2');
  });

  group('onLevelComplete (Phase 1 minimal)', () {
    test('updates highestCompletedLevel and currentLevel advance', () async {
      final p = RewardsProvider();
      await p.load();

      p.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 3,
        pendingScore: 150,
        isReplay: false,
      );

      expect(p.highestCompletedLevel[LanguageMode.russian], 3);
      expect(p.currentLevel[LanguageMode.russian], 4);
    });

    test('records best score and lifetime score', () async {
      final p = RewardsProvider();
      await p.load();

      p.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 1,
        pendingScore: 80,
        isReplay: false,
      );
      p.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 1,
        pendingScore: 120,
        isReplay: false,
      );

      expect(p.levelBestScore[LanguageMode.english]![1], 120);
      expect(p.lifetimeScore[LanguageMode.english], 200);
    });

    test('does not downgrade best score', () async {
      final p = RewardsProvider();
      await p.load();

      p.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 1,
        pendingScore: 150,
        isReplay: false,
      );
      p.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 1,
        pendingScore: 80,
        isReplay: false,
      );

      expect(p.levelBestScore[LanguageMode.russian]![1], 150);
    });
  });

  test('unlockAchievement adds id and is idempotent', () async {
    final p = RewardsProvider();
    await p.load();

    p.unlockAchievement('first_word');
    p.unlockAchievement('first_word');
    p.unlockAchievement('first_level');

    expect(p.achievementsUnlocked, {'first_word', 'first_level'});
  });

  group('freeHintEarnedTicks', () {
    test('fires tick when bonus counter fills and slot is not full', () async {
      final p = RewardsProvider();
      await p.load();
      expect(p.freeHintEarnedTicks.value, 0);
      for (var i = 0; i < 10; i++) {
        p.incrementBonusCounter();
      }
      expect(p.freeHintSlot, 1);
      expect(p.freeHintEarnedTicks.value, 1);
    });

    test('does not fire when slot cap is already hit', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 1,
        'rewards.bonusWordCounter': 9,
      });
      final p = RewardsProvider();
      await p.load();
      expect(p.freeHintEarnedTicks.value, 0);
      p.incrementBonusCounter(); // bonusWordCounter 9->10; slot already full; no tick
      expect(p.freeHintSlot, 1);
      expect(p.freeHintEarnedTicks.value, 0);
    });
  });
}
