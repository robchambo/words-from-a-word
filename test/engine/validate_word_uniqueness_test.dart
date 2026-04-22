import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/engine/game_engine.dart';
import 'package:slova_iz_slova/models/game_state.dart';

void main() {
  const bonusTarget = TargetWord(word: 'cat', length: 3, isBonus: true);
  const requiredTarget = TargetWord(word: 'cat', length: 3, isBonus: false);

  test('banked bonus word → alreadyUsedElsewhere', () {
    final r = GameEngine.validateWord(
      word: 'cat',
      sourceWord: 'catalogue',
      targetWords: const [bonusTarget],
      foundWords: const [],
      tooCommon: const [],
      bankedBonusesInLanguage: const {'cat'},
    );
    expect(r, WordValidationResult.alreadyUsedElsewhere);
  });

  test('banked word that is REQUIRED on this level still scores', () {
    final r = GameEngine.validateWord(
      word: 'cat',
      sourceWord: 'catalogue',
      targetWords: const [requiredTarget],
      foundWords: const [],
      tooCommon: const [],
      bankedBonusesInLanguage: const {'cat'},
    );
    expect(r, WordValidationResult.found);
  });

  test('unbanked bonus word still returns bonus', () {
    final r = GameEngine.validateWord(
      word: 'cat',
      sourceWord: 'catalogue',
      targetWords: const [bonusTarget],
      foundWords: const [],
      tooCommon: const [],
      bankedBonusesInLanguage: const {'dog'},
    );
    expect(r, WordValidationResult.bonus);
  });

  test('default empty set preserves existing behaviour', () {
    final r = GameEngine.validateWord(
      word: 'cat',
      sourceWord: 'catalogue',
      targetWords: const [bonusTarget],
      foundWords: const [],
      tooCommon: const [],
    );
    expect(r, WordValidationResult.bonus);
  });
}
