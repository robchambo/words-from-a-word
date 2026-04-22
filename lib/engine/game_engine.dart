import 'dart:math';

import '../models/game_state.dart';

class GameEngine {
  static final _rng = Random();

  static Map<String, int> letterCount(String word) {
    final counts = <String, int>{};
    for (final ch in word.toLowerCase().split('')) {
      counts[ch] = (counts[ch] ?? 0) + 1;
    }
    return counts;
  }

  static bool canFormWord(String sub, String source) {
    final srcCount = letterCount(source);
    final subCount = letterCount(sub);
    for (final entry in subCount.entries) {
      if ((srcCount[entry.key] ?? 0) < entry.value) return false;
    }
    return true;
  }

  static WordValidationResult validateWord({
    required String word,
    required String sourceWord,
    required List<TargetWord> targetWords,
    required List<String> foundWords,
    required List<String> tooCommon,
    Set<String> bankedBonusesInLanguage = const {},
  }) {
    final w = word.toLowerCase();
    if (foundWords.contains(w)) return WordValidationResult.alreadyFound;
    if (!canFormWord(w, sourceWord)) return WordValidationResult.invalid;
    if (tooCommon.contains(w)) return WordValidationResult.tooCommon;

    final target = targetWords.cast<TargetWord?>().firstWhere(
          (t) => t!.word == w,
          orElse: () => null,
        );

    if (target == null) return WordValidationResult.invalid;
    // Uniqueness rule applies ONLY to bonus words. Required words can re-appear
    // across levels and score normally each time.
    if (target.isBonus && bankedBonusesInLanguage.contains(w)) {
      return WordValidationResult.alreadyUsedElsewhere;
    }
    if (target.isBonus) return WordValidationResult.bonus;
    return WordValidationResult.found;
  }

  static const int _bonusWordFlatScore = 15; // TODO(phase-6): read from RemoteConfigService.bonusWordFlatScore

  static int scoreWord(String word, {required bool isBonus}) {
    if (isBonus) {
      return _bonusWordFlatScore;
    }
    final n = word.length;
    int lengthBonus;
    if (n >= 6) {
      lengthBonus = 30;
    } else if (n == 5) {
      lengthBonus = 20;
    } else if (n == 4) {
      lengthBonus = 10;
    } else {
      lengthBonus = 0;
    }
    return n * 10 + lengthBonus;
  }

  static bool isLevelComplete(List<TargetWord> targetWords) {
    return targetWords.where((w) => !w.isBonus).every((w) => w.isFound);
  }

  static List<T> shuffleList<T>(List<T> list) {
    final a = List<T>.from(list);
    for (int i = a.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final tmp = a[i];
      a[i] = a[j];
      a[j] = tmp;
    }
    return a;
  }

  static SafeHintResult? pickSafeHintLetter({
    required List<TargetWord> targetWords,
    required Map<String, Set<int>> revealedPositions,
    required Random rng,
  }) {
    final candidates = <SafeHintResult>[];
    for (final tw in targetWords) {
      if (tw.isFound) continue;
      // Bonus words are hidden from the UI until found, so revealing a
      // letter in a bonus word is invisible to the player. Guide hints
      // toward the required-word list only.
      if (tw.isBonus) continue;
      final revealed = revealedPositions[tw.word] ?? const <int>{};
      final unrevealed = <int>[];
      for (var i = 0; i < tw.word.length; i++) {
        if (!revealed.contains(i)) unrevealed.add(i);
      }
      // Safe if at least 2 unrevealed positions remain —
      // revealing one leaves ≥ 1 so the player still has to find the last letter.
      if (unrevealed.length < 2) continue;
      for (final i in unrevealed) {
        candidates.add(SafeHintResult(
          wordKey: tw.word,
          position: i,
          letter: tw.word[i],
        ));
      }
    }
    if (candidates.isEmpty) return null;
    return candidates[rng.nextInt(candidates.length)];
  }
}

class SafeHintResult {
  final String wordKey;
  final int position;
  final String letter;
  const SafeHintResult({
    required this.wordKey,
    required this.position,
    required this.letter,
  });
}
