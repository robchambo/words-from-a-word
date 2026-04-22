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

  test('bankAndAdvance commits pendingScore to lifetime when level complete',
      () async {
    final rewards = RewardsProvider();
    await rewards.load();
    final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway(), rng: Random(1));
    await game.startGame(LanguageMode.english);

    // Submit every required word in the level.
    final required = game.state.level.targetWords
        .where((tw) => !tw.isBonus)
        .map((tw) => tw.word)
        .toList();
    for (final w in required) {
      await _submitWord(game, w);
    }
    expect(game.state.isLevelComplete, isTrue);
    final banked = game.state.pendingScore;
    expect(banked, greaterThan(0));

    await game.bankAndAdvance(LanguageMode.english);

    expect(rewards.lifetimeScore[LanguageMode.english], banked);
    expect(rewards.highestCompletedLevel[LanguageMode.english], 1);
  });

  test('starting a new level without banking discards pendingScore', () async {
    final rewards = RewardsProvider();
    await rewards.load();
    final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway(), rng: Random(1));
    await game.startGame(LanguageMode.english);

    // Submit one word so pendingScore > 0.
    final first = game.state.level.targetWords
        .where((tw) => !tw.isBonus)
        .first
        .word;
    await _submitWord(game, first);
    expect(game.state.pendingScore, greaterThan(0));
    expect(game.state.isLevelComplete, isFalse);

    // Abandon — start a new level. No bank call.
    await game.startGame(LanguageMode.english, levelNumber: 2);

    expect(rewards.lifetimeScore[LanguageMode.english] ?? 0, 0);
    expect(game.state.pendingScore, 0);
  });

  test('finding a bonus is provisional until bankAndAdvance', () async {
    final rewards = RewardsProvider();
    await rewards.load();
    expect(rewards.bonusWordCounter, 0);
    final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway(), rng: Random(1));
    await game.startGame(LanguageMode.english);

    final bonus = game.state.level.targetWords
        .where((tw) => tw.isBonus)
        .map((tw) => tw.word)
        .toList();
    if (bonus.isEmpty) {
      // If the first English level has no bonus words, skip this assertion.
      // The counter wiring is still verified by rewards_provider_test.dart.
      return;
    }
    await _submitWord(game, bonus.first);
    // Counter should NOT tick yet — bonus is provisional until bankAndAdvance.
    expect(rewards.bonusWordCounter, 0);

    // Find all required words to complete the level.
    final required = game.state.level.targetWords
        .where((tw) => !tw.isBonus)
        .map((tw) => tw.word)
        .toList();
    for (final w in required) {
      await _submitWord(game, w);
    }
    expect(game.state.isLevelComplete, isTrue);

    await game.bankAndAdvance(LanguageMode.english);
    // Now the counter should tick once for the one bonus found.
    expect(rewards.bonusWordCounter, 1);
  });
}

/// Select tiles from the source row that spell `word` (left-to-right,
/// consuming the first unselected tile matching each letter), then submit.
Future<void> _submitWord(GameProvider game, String word) async {
  final lower = word.toLowerCase();
  for (final ch in lower.split('')) {
    final tile = game.state.level.sourceLetters.firstWhere(
      (t) => !t.isSelected && !t.isUsed && t.letter.toLowerCase() == ch,
      orElse: () => throw StateError('no tile for letter $ch'),
    );
    game.selectTile(tile.id);
  }
  game.submitWord();
}
