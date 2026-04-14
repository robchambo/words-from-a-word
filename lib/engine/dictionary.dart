import 'package:flutter/services.dart';

import '../models/language_mode.dart';

enum WordClass { required, bonus, excluded }

class Dictionary {
  // Tune these constants to adjust classification behaviour
  static const int maxRequiredLength = 6;
  static const int minSourceWordLength = 12;
  static const int frequencyThreshold = 1000; // TODO: tune after data review

  static Map<String, int> _ruFreq = {};

  static Future<void> preload() async {
    _ruFreq = await _loadFreqFile('assets/data/ru_freq.txt');
  }

  static Future<Map<String, int>> _loadFreqFile(String path) async {
    final raw = await rootBundle.loadString(path);
    final map = <String, int>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final spaceIdx = trimmed.lastIndexOf(' ');
      if (spaceIdx < 1) continue;
      final word = trimmed.substring(0, spaceIdx).toLowerCase();
      final freq = int.tryParse(trimmed.substring(spaceIdx + 1));
      if (freq != null && word.isNotEmpty) map[word] = freq;
    }
    return map;
  }

  /// Classifies [word] as required, bonus, or excluded.
  /// Words in [overrideExcluded] are always excluded regardless of frequency.
  static WordClass classify(
    String word, {
    required LanguageMode mode,
    Set<String> overrideExcluded = const {},
  }) {
    final w = word.toLowerCase();
    if (overrideExcluded.contains(w)) return WordClass.excluded;
    final freq = _freqMap(mode)[w] ?? 0;
    if (freq == 0) return WordClass.excluded;
    if (w.length <= maxRequiredLength && freq >= frequencyThreshold) {
      return WordClass.required;
    }
    return WordClass.bonus;
  }

  static int frequency(String word, LanguageMode mode) =>
      _freqMap(mode)[word.toLowerCase()] ?? 0;

  /// Returns all dictionary words that can be formed from [sourceWord]'s letters,
  /// excluding the source word itself and words shorter than 3 letters.
  static List<String> formableWords(String sourceWord, LanguageMode mode) {
    final src = sourceWord.toLowerCase();
    final srcCount = _letterCount(src);
    final srcLetterSet = srcCount.keys.toSet();
    final result = <String>[];

    for (final word in _freqMap(mode).keys) {
      if (word.length < 3 || word.length >= src.length) continue;
      if (word.split('').any((c) => !srcLetterSet.contains(c))) continue;
      if (_canForm(word, srcCount)) result.add(word);
    }
    return result;
  }

  static Map<String, int> _letterCount(String word) {
    final counts = <String, int>{};
    for (final ch in word.split('')) {
      counts[ch] = (counts[ch] ?? 0) + 1;
    }
    return counts;
  }

  static bool _canForm(String word, Map<String, int> srcCount) {
    final wc = _letterCount(word);
    for (final entry in wc.entries) {
      if ((srcCount[entry.key] ?? 0) < entry.value) return false;
    }
    return true;
  }

  static Map<String, int> _freqMap(LanguageMode mode) {
    switch (mode) {
      case LanguageMode.russian:
        return _ruFreq;
      case LanguageMode.english:
        return {}; // TODO: add English frequency list
    }
  }
}
