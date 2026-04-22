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
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LevelLoader.preload();
  });

  test('replay of completed level pre-fills required words', () async {
    final r = RewardsProvider();
    await r.load();
    r.highestCompletedLevel[LanguageMode.english] = 1;
    final g = GameProvider(rewards: r, adGateway: NoopAdGateway(), rng: Random(1));
    await g.startGame(LanguageMode.english, levelNumber: 1, isReplay: true);

    final required =
        g.state.level.targetWords.where((tw) => !tw.isBonus).toList();
    expect(required.every((tw) => tw.isFound), true);
  });

  test('replay-of-completed: finding a new bonus banks immediately', () async {
    final r = RewardsProvider();
    await r.load();
    r.highestCompletedLevel[LanguageMode.english] = 1;
    final g = GameProvider(rewards: r, adGateway: NoopAdGateway(), rng: Random(1));
    await g.startGame(LanguageMode.english, levelNumber: 1, isReplay: true);

    final bonus = g.state.level.targetWords
        .where((tw) => tw.isBonus && !tw.isFound)
        .toList();
    if (bonus.isEmpty) return;
    final word = bonus.first.word;

    final lifetimeBefore = r.lifetimeScore[LanguageMode.english] ?? 0;
    final counterBefore = r.bonusWordCounter;
    await _submitWord(g, word);

    expect(r.bankedBonusWords[LanguageMode.english]![1]?.contains(word), true);
    expect(r.lifetimeScore[LanguageMode.english], greaterThan(lifetimeBefore));
    expect(r.bonusWordCounter, counterBefore + 1);
  });

  test('replay-of-completed: re-submitting an already-banked bonus is rejected',
      () async {
    final r = RewardsProvider();
    await r.load();
    r.highestCompletedLevel[LanguageMode.english] = 1;
    final g = GameProvider(rewards: r, adGateway: NoopAdGateway(), rng: Random(1));

    // Pre-bank a bonus at level 1.
    await g.startGame(LanguageMode.english, levelNumber: 1);
    final bonus = g.state.level.targetWords
        .where((tw) => tw.isBonus)
        .toList();
    if (bonus.isEmpty) return;
    final word = bonus.first.word;
    r.bankBonusWords(
        mode: LanguageMode.english, levelId: 1, words: [word]);

    // Now enter replay; the pre-banked bonus should already be marked found.
    await g.startGame(LanguageMode.english, levelNumber: 1, isReplay: true);
    final lifetimeBefore = r.lifetimeScore[LanguageMode.english] ?? 0;
    final pendingBefore = g.state.pendingScore;

    await _submitWord(g, word);

    // Already-banked bonus is pre-filled as found, so submitting it will
    // trigger either alreadyFound or alreadyUsedElsewhere depending on order
    // of guards. Either way: no new banking, no new lifetime score.
    expect(r.bankedBonusWords[LanguageMode.english]![1]!.length, 1);
    expect(r.lifetimeScore[LanguageMode.english], lifetimeBefore);
    expect(g.state.pendingScore, pendingBefore);
  });

  test(
      'replay of NON-completed level (levelNumber > highestCompleted): no pre-fill',
      () async {
    final r = RewardsProvider();
    await r.load();
    r.highestCompletedLevel[LanguageMode.english] = 0;
    final g = GameProvider(rewards: r, adGateway: NoopAdGateway(), rng: Random(1));
    await g.startGame(LanguageMode.english, levelNumber: 1, isReplay: true);

    final required =
        g.state.level.targetWords.where((tw) => !tw.isBonus).toList();
    expect(required.every((tw) => !tw.isFound), true);
  });
}

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
