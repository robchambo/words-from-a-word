import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/engine/game_engine.dart';
import 'package:slova_iz_slova/models/game_state.dart';

void main() {
  group('pickSafeHintLetter', () {
    TargetWord tw(String word, {bool isBonus = false, bool isFound = false}) =>
        TargetWord(
          word: word,
          length: word.length,
          isFound: isFound,
          isBonus: isBonus,
        );

    test('picks from any unfound word where revealing leaves ≥ 1 unrevealed',
        () {
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('star'), tw('strand')],
        revealedPositions: {},
        rng: Random(42),
      );
      expect(result, isNotNull);
      expect(result!.wordKey, anyOf('star', 'strand'));
      expect(
          result.position >= 0 && result.position < result.wordKey.length,
          true);
    });

    test('returns null when every unfound word is one-letter-from-complete',
        () {
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('cat')],
        revealedPositions: {
          'cat': {0, 1}
        },
        rng: Random(42),
      );
      expect(result, isNull);
    });

    test('skips found words', () {
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('cat', isFound: true), tw('dogs')],
        revealedPositions: {},
        rng: Random(42),
      );
      expect(result, isNotNull);
      expect(result!.wordKey, 'dogs');
    });

    test('skips bonus words (they are hidden from the slot list)', () {
      // A reveal on a hidden bonus word would be invisible to the player —
      // guide hints toward required words only.
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('cats', isBonus: true)],
        revealedPositions: {},
        rng: Random(42),
      );
      expect(result, isNull);
    });

    test('prefers required words even when bonus words are present', () {
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [
          tw('cats', isBonus: true),
          tw('dogs'),
        ],
        revealedPositions: {},
        rng: Random(42),
      );
      expect(result, isNotNull);
      expect(result!.wordKey, 'dogs');
    });

    test('seeded RNG is deterministic', () {
      final a = GameEngine.pickSafeHintLetter(
        targetWords: [tw('bread'), tw('table')],
        revealedPositions: {},
        rng: Random(1234),
      );
      final b = GameEngine.pickSafeHintLetter(
        targetWords: [tw('bread'), tw('table')],
        revealedPositions: {},
        rng: Random(1234),
      );
      expect(a!.wordKey, b!.wordKey);
      expect(a.position, b.position);
    });

    test('returns null when only one letter remains unrevealed', () {
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('cat')],
        revealedPositions: {
          'cat': {0, 1}
        },
        rng: Random(42),
      );
      expect(result, isNull);
    });
  });
}
