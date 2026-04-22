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

  test('submitWord does NOT immediately bank a bonus', () async {
    final r = RewardsProvider();
    await r.load();
    final g = GameProvider(rewards: r, adGateway: NoopAdGateway(), rng: Random(1));
    await g.startGame(LanguageMode.english, levelNumber: 1);

    final bonus = g.state.level.targetWords.where((tw) => tw.isBonus).toList();
    if (bonus.isEmpty) return; // no bonus on this level; skip
    await _submitWord(g, bonus.first.word);
    expect(r.bankedBonusWords[LanguageMode.english]!.isEmpty, true);
    expect(r.bonusWordCounter, 0);
  });

  test('bankAndAdvance banks all session bonuses + ticks hint counter', () async {
    final r = RewardsProvider();
    await r.load();
    final g = GameProvider(rewards: r, adGateway: NoopAdGateway(), rng: Random(1));
    await g.startGame(LanguageMode.english, levelNumber: 1);

    // Find every required and every bonus.
    final targets = g.state.level.targetWords.map((tw) => tw.word).toList();
    for (final w in targets) {
      await _submitWord(g, w);
    }
    expect(g.state.isLevelComplete, isTrue);
    final bonusCount =
        g.state.level.targetWords.where((tw) => tw.isBonus && tw.isFound).length;

    await g.bankAndAdvance(LanguageMode.english);

    if (bonusCount > 0) {
      expect(r.bankedBonusWords[LanguageMode.english]![1], isNotEmpty);
      expect(r.bankedBonusWords[LanguageMode.english]![1]!.length, bonusCount);
      // bonusWordCounter wraps back toward 0 each time it hits the refill
      // threshold (10), earning a free hint. Assert the counter is in the valid
      // post-banking range: either it equals bonusCount (< 10 bonuses) or it
      // is capped at the threshold (≥ 10 bonuses; slot full or earned).
      if (bonusCount < 10) {
        expect(r.bonusWordCounter, bonusCount);
      } else {
        // At least one hint-earning cycle must have occurred.
        expect(r.bonusWordCounter, lessThanOrEqualTo(10));
      }
    }
  });

  test('abandoning level (no bankAndAdvance) does NOT bank bonuses', () async {
    final r = RewardsProvider();
    await r.load();
    final g = GameProvider(rewards: r, adGateway: NoopAdGateway(), rng: Random(1));
    await g.startGame(LanguageMode.english, levelNumber: 1);

    final bonus = g.state.level.targetWords.where((tw) => tw.isBonus).toList();
    if (bonus.isEmpty) return;
    await _submitWord(g, bonus.first.word);

    // Abandon: start a new level without banking.
    await g.startGame(LanguageMode.english, levelNumber: 2);

    expect(r.bankedBonusWords[LanguageMode.english]!.isEmpty, true);
    expect(r.bonusWordCounter, 0);
  });

  test('submitting an already-banked bonus → alreadyUsedWord set, no score change',
      () async {
    final r = RewardsProvider();
    await r.load();
    final g = GameProvider(rewards: r, adGateway: NoopAdGateway(), rng: Random(1));
    await g.startGame(LanguageMode.english, levelNumber: 1);

    final bonus = g.state.level.targetWords.where((tw) => tw.isBonus).toList();
    if (bonus.isEmpty) return;
    // Pre-bank this bonus at some other level.
    r.bankBonusWords(
      mode: LanguageMode.english, levelId: 99, words: [bonus.first.word]);

    final scoreBefore = g.state.pendingScore;
    await _submitWord(g, bonus.first.word);
    expect(g.state.alreadyUsedWord, bonus.first.word);
    expect(g.state.alreadyUsedInLevel, 99);
    expect(g.state.pendingScore, scoreBefore);
    // foundWords should NOT include the rejected word.
    expect(g.state.foundWords.contains(bonus.first.word), isFalse);
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
