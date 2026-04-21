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
}
