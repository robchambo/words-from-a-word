import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../models/language_mode.dart';
import '../engine/game_engine.dart';
import '../engine/level_loader.dart';

class GameProvider extends ChangeNotifier {
  GameState? _state;
  GameState get state => _state!;
  bool get isReady => _state != null;

  int _currentLevelIndex = 1; // Global 1-based position in the level array.

  Timer? _shakeTimer;
  Timer? _lastFoundTimer;
  Timer? _tooCommonTimer;

  Future<void> startGame(LanguageMode mode, {int levelNumber = 1}) async {
    _currentLevelIndex = levelNumber;
    final level = LevelLoader.generateLevel(_currentLevelIndex, mode);
    _state = GameState(level: level);
    notifyListeners();
  }

  void selectTile(String tileId) {
    final s = _state!;
    final tile = s.level.sourceLetters.firstWhere((t) => t.id == tileId);
    if (tile.isUsed || tile.isSelected) return;

    HapticFeedback.selectionClick();

    final newSelected = [...s.selectedTileIds, tileId];
    final newInput = newSelected
        .map((id) =>
            s.level.sourceLetters.firstWhere((t) => t.id == id).letter)
        .join();

    _state = s.copyWith(
      selectedTileIds: newSelected,
      currentInput: newInput,
      level: s.level.copyWith(
        sourceLetters: s.level.sourceLetters
            .map((t) =>
                t.id == tileId ? t.copyWith(isSelected: true) : t)
            .toList(),
      ),
    );
    notifyListeners();
  }

  void deselectTile(String tileId) {
    final s = _state!;
    final idx = s.selectedTileIds.indexOf(tileId);
    if (idx == -1) return;

    final newSelected = s.selectedTileIds.sublist(0, idx);
    final newInput = newSelected
        .map((id) =>
            s.level.sourceLetters.firstWhere((t) => t.id == id).letter)
        .join();
    final deselectedIds = s.selectedTileIds.sublist(idx);

    _state = s.copyWith(
      selectedTileIds: newSelected,
      currentInput: newInput,
      level: s.level.copyWith(
        sourceLetters: s.level.sourceLetters
            .map((t) => deselectedIds.contains(t.id)
                ? t.copyWith(isSelected: false)
                : t)
            .toList(),
      ),
    );
    notifyListeners();
  }

  void clearSelection() {
    final s = _state!;
    _state = s.copyWith(
      selectedTileIds: [],
      currentInput: '',
      level: s.level.copyWith(
        sourceLetters: s.level.sourceLetters
            .map((t) => t.copyWith(isSelected: false))
            .toList(),
      ),
    );
    notifyListeners();
  }

  void submitWord() {
    final s = _state!;
    final word = s.currentInput.toLowerCase();
    if (word.length < 3) return;

    final result = GameEngine.validateWord(
      word: word,
      sourceWord: s.level.sourceWord,
      targetWords: s.level.targetWords,
      foundWords: s.foundWords,
      tooCommon: s.level.tooCommon,
    );

    if (result == WordValidationResult.invalid ||
        result == WordValidationResult.alreadyFound) {
      HapticFeedback.heavyImpact();
      _state = s.copyWith(isShaking: true);
      notifyListeners();

      _shakeTimer?.cancel();
      _shakeTimer = Timer(const Duration(milliseconds: 400), () {
        _state = _state!.copyWith(isShaking: false);
        notifyListeners();
      });
      return;
    }

    if (result == WordValidationResult.tooCommon) {
      HapticFeedback.lightImpact();
      _state = s.copyWith(
        selectedTileIds: [],
        currentInput: '',
        tooCommonWord: word,
        level: s.level.copyWith(
          sourceLetters: s.level.sourceLetters
              .map((t) => t.copyWith(isSelected: false))
              .toList(),
        ),
      );
      notifyListeners();

      _tooCommonTimer?.cancel();
      _tooCommonTimer = Timer(const Duration(milliseconds: 1500), () {
        _state = _state!.copyWith(clearTooCommonWord: true);
        notifyListeners();
      });
      return;
    }

    HapticFeedback.mediumImpact();

    final points = GameEngine.scoreWord(word);
    final newFoundWords = [...s.foundWords, word];
    final updatedTargetWords = s.level.targetWords
        .map((tw) => tw.word == word ? tw.copyWith(isFound: true) : tw)
        .toList();

    final updatedLetters = s.level.sourceLetters
        .map((t) => s.selectedTileIds.contains(t.id)
            ? t.copyWith(isSelected: false)
            : t)
        .toList();

    final newLevel = s.level.copyWith(
      sourceLetters: updatedLetters,
      targetWords: updatedTargetWords,
    );

    final levelDone = GameEngine.isLevelComplete(updatedTargetWords);

    _state = s.copyWith(
      level: newLevel,
      selectedTileIds: [],
      currentInput: '',
      foundWords: newFoundWords,
      score: s.score + points,
      isLevelComplete: levelDone,
      lastFoundWord: word,
    );
    notifyListeners();

    _lastFoundTimer?.cancel();
    _lastFoundTimer = Timer(const Duration(milliseconds: 1500), () {
      _state = _state!.copyWith(clearLastFoundWord: true);
      notifyListeners();
    });
  }

  void shuffleTiles() {
    final s = _state!;
    final shuffled =
        GameEngine.shuffleList(List<LetterTile>.from(s.level.sourceLetters));
    _state =
        s.copyWith(level: s.level.copyWith(sourceLetters: shuffled));
    notifyListeners();
  }

  void useHint() {
    final s = _state!;
    if (s.hintsRemaining <= 0) return;

    final unfoundRequired = s.level.targetWords
        .where((w) => !w.isFound && !w.isBonus)
        .toList();
    if (unfoundRequired.isEmpty) return;

    // Count total occurrences of each letter that hasn't been hinted yet
    final letterCounts = <String, int>{};
    for (final tw in unfoundRequired) {
      for (final ch in tw.word.split('')) {
        if ((s.hintedLetterCounts[ch] ?? 0) == 0) {
          letterCounts[ch] = (letterCounts[ch] ?? 0) + 1;
        }
      }
    }
    if (letterCounts.isEmpty) return;

    // Pick letter with most occurrences across unfound required words
    final hintLetter = letterCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    // Reveal ALL occurrences of hintLetter in each unfound required word
    final updatedTargetWords = s.level.targetWords.map((tw) {
      if (tw.isFound || tw.isBonus) return tw;
      final newIndices = <int>{...tw.revealedIndices};
      for (int i = 0; i < tw.word.length; i++) {
        if (tw.word[i] == hintLetter) newIndices.add(i);
      }
      if (newIndices.length == tw.revealedIndices.length) return tw;
      return tw.copyWith(revealedIndices: newIndices);
    }).toList();

    final newHintedLetterCounts =
        Map<String, int>.from(s.hintedLetterCounts)
          ..[hintLetter] = 1;

    _state = s.copyWith(
      hintsRemaining: s.hintsRemaining - 1,
      hintedLetterCounts: newHintedLetterCounts,
      level: s.level.copyWith(targetWords: updatedTargetWords),
    );
    notifyListeners();
  }

  void nextLevel(LanguageMode mode) {
    final savedScore = _state!.score;
    final savedHints = _state!.hintsRemaining;
    _currentLevelIndex++;
    final level = LevelLoader.generateLevel(_currentLevelIndex, mode);
    _state = GameState(
      level: level,
      score: savedScore,
      hintsRemaining: savedHints,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _lastFoundTimer?.cancel();
    _tooCommonTimer?.cancel();
    super.dispose();
  }
}
