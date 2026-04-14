import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../models/language_mode.dart';
import 'game_engine.dart';

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

    // canFormWord is a safety net — silently drops any word the generator
    // may have incorrectly included, without crashing at runtime.
    final required = List<String>.from(def['required'] ?? [])
        .where((w) => GameEngine.canFormWord(w, sourceWord))
        .toList();
    final bonus = List<String>.from(def['bonus'] ?? [])
        .where((w) => GameEngine.canFormWord(w, sourceWord))
        .toList();
    final tooCommon = List<String>.from(def['tooCommon'] ?? [])
        .where((w) => GameEngine.canFormWord(w, sourceWord))
        .toList();

    final targetWords = [
      ...required.map((w) => TargetWord(word: w, length: w.length)),
      ...bonus.map((w) => TargetWord(word: w, length: w.length, isBonus: true)),
    ];

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
      tooCommon: tooCommon,
      totalWords: required.length,
    );
  }
}
