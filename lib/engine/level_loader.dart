import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../models/language_mode.dart';
import 'dictionary.dart';

class LevelLoader {
  static List<Map<String, dynamic>>? _russianDefs;
  static List<Map<String, dynamic>>? _englishDefs;

  static Future<void> preload() async {
    final ruJson =
        await rootBundle.loadString('assets/data/russian_levels.json');
    final enJson =
        await rootBundle.loadString('assets/data/english_levels.json');
    _russianDefs = List<Map<String, dynamic>>.from(jsonDecode(ruJson));
    _englishDefs = List<Map<String, dynamic>>.from(jsonDecode(enJson));
  }

  static int levelCount(LanguageMode mode) {
    final defs =
        mode == LanguageMode.russian ? _russianDefs! : _englishDefs!;
    return defs.length;
  }

  static GameLevel generateLevel(int levelNumber, LanguageMode mode) {
    final defs =
        mode == LanguageMode.russian ? _russianDefs! : _englishDefs!;
    final def = defs[(levelNumber - 1) % defs.length];

    final sourceWord = def['sourceWord'] as String;
    final overrideExcluded = Set<String>.from(
      ((def['overrides']?['excluded']) as List? ?? [])
          .map((e) => e.toString().toLowerCase()),
    );

    final formable = Dictionary.formableWords(sourceWord, mode);

    final targetWords = formable
        .map((word) {
          final wc = Dictionary.classify(
            word,
            mode: mode,
            overrideExcluded: overrideExcluded,
          );
          if (wc == WordClass.excluded) return null;
          return TargetWord(
            word: word,
            length: word.length,
            isBonus: wc == WordClass.bonus,
          );
        })
        .whereType<TargetWord>()
        .toList();

    final letters = sourceWord.toLowerCase().split('');
    final sourceLetters = letters.asMap().entries.map((e) {
      return LetterTile(
        id: 'tile-${e.key}-${e.value}-$levelNumber',
        letter: e.value,
      );
    }).toList();

    return GameLevel(
      id: levelNumber,
      sourceWord: sourceWord,
      sourceLetters: sourceLetters,
      targetWords: targetWords,
      totalWords: targetWords.where((w) => !w.isBonus).length,
    );
  }
}
