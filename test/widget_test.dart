import 'package:flutter_test/flutter_test.dart';

import 'package:slova_iz_slova/engine/game_engine.dart';
import 'package:slova_iz_slova/models/game_state.dart';

void main() {
  group('GameEngine', () {
    test('letterCount counts correctly', () {
      expect(GameEngine.letterCount('hello'), {'h': 1, 'e': 1, 'l': 2, 'o': 1});
    });

    test('canFormWord - valid', () {
      expect(GameEngine.canFormWord('вод', 'переводчик'), true);
      expect(GameEngine.canFormWord('bar', 'strawberry'), true);
    });

    test('canFormWord - invalid', () {
      expect(GameEngine.canFormWord('xxx', 'переводчик'), false);
      expect(GameEngine.canFormWord('folk', 'fireworks'), false);
    });

    test('validateWord - found', () {
      final targets = [
        const TargetWord(word: 'bar', length: 3),
        const TargetWord(word: 'star', length: 4),
      ];
      expect(
        GameEngine.validateWord(
          word: 'bar',
          sourceWord: 'strawberry',
          targetWords: targets,
          foundWords: [],
        ),
        WordValidationResult.found,
      );
    });

    test('validateWord - already found', () {
      final targets = [
        const TargetWord(word: 'bar', length: 3),
      ];
      expect(
        GameEngine.validateWord(
          word: 'bar',
          sourceWord: 'strawberry',
          targetWords: targets,
          foundWords: ['bar'],
        ),
        WordValidationResult.alreadyFound,
      );
    });

    test('validateWord - bonus', () {
      final targets = [
        const TargetWord(word: 'berry', length: 5, isBonus: true),
      ];
      expect(
        GameEngine.validateWord(
          word: 'berry',
          sourceWord: 'strawberry',
          targetWords: targets,
          foundWords: [],
        ),
        WordValidationResult.bonus,
      );
    });

    test('validateWord - invalid word not in targets', () {
      final targets = [
        const TargetWord(word: 'bar', length: 3),
      ];
      expect(
        GameEngine.validateWord(
          word: 'raw',
          sourceWord: 'strawberry',
          targetWords: targets,
          foundWords: [],
        ),
        WordValidationResult.invalid,
      );
    });

    test('scoreWord scoring', () {
      expect(GameEngine.scoreWord('bar'), 30); // 3 * 10 + 0
      expect(GameEngine.scoreWord('star'), 50); // 4 * 10 + 10
      expect(GameEngine.scoreWord('stare'), 70); // 5 * 10 + 20
      expect(GameEngine.scoreWord('arrest'), 90); // 6 * 10 + 30
    });

    test('isLevelComplete', () {
      final incomplete = [
        const TargetWord(word: 'bar', length: 3, isFound: true),
        const TargetWord(word: 'star', length: 4, isFound: false),
        const TargetWord(word: 'berry', length: 5, isBonus: true, isFound: false),
      ];
      expect(GameEngine.isLevelComplete(incomplete), false);

      final complete = [
        const TargetWord(word: 'bar', length: 3, isFound: true),
        const TargetWord(word: 'star', length: 4, isFound: true),
        const TargetWord(word: 'berry', length: 5, isBonus: true, isFound: false),
      ];
      expect(GameEngine.isLevelComplete(complete), true);
    });

    test('shuffleList returns all elements', () {
      final list = [1, 2, 3, 4, 5];
      final shuffled = GameEngine.shuffleList(list);
      expect(shuffled.length, list.length);
      expect(shuffled.toSet(), list.toSet());
    });
  });
}
