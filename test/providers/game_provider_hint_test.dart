import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/engine/level_loader.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/game_provider.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/services/ad_gateway.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    await LevelLoader.preload();
  });

  group('GameProvider.useHint', () {
    test('hintAvailable is true at level start (many safe positions)', () async {
      final rewards = RewardsProvider();
      await rewards.load();
      final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway(), rng: Random(1));
      await game.startGame(LanguageMode.english);
      expect(game.hintAvailable, isTrue);
    });

    test('consumes free slot when available and reveals a position', () async {
      SharedPreferences.setMockInitialValues({'rewards.freeHintSlot': 1});
      final rewards = RewardsProvider();
      await rewards.load();
      final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway(), rng: Random(1));
      await game.startGame(LanguageMode.english);

      final beforeSlot = rewards.freeHintSlot;
      final revealCountBefore = game.state.level.targetWords
          .fold<int>(0, (acc, tw) => acc + tw.revealedIndices.length);

      game.useHint();

      expect(rewards.freeHintSlot, beforeSlot - 1);
      final revealCountAfter = game.state.level.targetWords
          .fold<int>(0, (acc, tw) => acc + tw.revealedIndices.length);
      expect(revealCountAfter, revealCountBefore + 1);
      expect(game.state.pendingRewardedAdPrompt, isFalse);
    });

    test('sets pendingRewardedAdPrompt when no free or purchased hint is available',
        () async {
      // Seed lastDailyClaimedOn to today so maybeRefillDailyHint does not grant
      // a slot — freeHintSlot stays 0 and consumeHint returns null.
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'rewards.lastDailyClaimedOn': todayStr,
      });
      final rewards = RewardsProvider();
      await rewards.load();
      // freeHintSlot = 0, purchasedHintCount = 0 → consumeHint returns null.
      final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway(), rng: Random(1));
      await game.startGame(LanguageMode.english);

      game.useHint();

      expect(game.state.pendingRewardedAdPrompt, isTrue);
      // No reveal happened.
      final revealCount = game.state.level.targetWords
          .fold<int>(0, (acc, tw) => acc + tw.revealedIndices.length);
      expect(revealCount, 0);
    });

    test('onRewardedAdCompleted grants a hint and reveals', () async {
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'rewards.lastDailyClaimedOn': todayStr,
      });
      final rewards = RewardsProvider();
      await rewards.load();
      final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway(), rng: Random(1));
      await game.startGame(LanguageMode.english);
      game.useHint(); // sets flag
      expect(game.state.pendingRewardedAdPrompt, isTrue);

      game.onRewardedAdCompleted();

      expect(game.state.pendingRewardedAdPrompt, isFalse);
      final revealCount = game.state.level.targetWords
          .fold<int>(0, (acc, tw) => acc + tw.revealedIndices.length);
      expect(revealCount, 1);
    });

    test('onRewardedAdDeclined clears the flag without revealing', () async {
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'rewards.lastDailyClaimedOn': todayStr,
      });
      final rewards = RewardsProvider();
      await rewards.load();
      final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway(), rng: Random(1));
      await game.startGame(LanguageMode.english);
      game.useHint();
      expect(game.state.pendingRewardedAdPrompt, isTrue);

      game.onRewardedAdDeclined();

      expect(game.state.pendingRewardedAdPrompt, isFalse);
      final revealCount = game.state.level.targetWords
          .fold<int>(0, (acc, tw) => acc + tw.revealedIndices.length);
      expect(revealCount, 0);
    });

    test('startGame triggers maybeRefillDailyHint', () async {
      // freeHintSlot=0 and never-claimed → refill should fire.
      final rewards = RewardsProvider();
      await rewards.load();
      expect(rewards.freeHintSlot, 0);
      final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway());
      await game.startGame(LanguageMode.english);
      expect(rewards.freeHintSlot, 1);
    });
  });
}
