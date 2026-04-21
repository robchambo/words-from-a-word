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

    final foundTarget = s.level.targetWords.firstWhere((tw) => tw.word == word);
    final points = GameEngine.scoreWord(word, isBonus: foundTarget.isBonus);
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
      pendingScore: s.pendingScore + points,
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
    // Real impl lands in Task 5 once RewardsProvider is wired.
  }

  void nextLevel(LanguageMode mode) {
    final savedPendingScore = _state!.pendingScore;
    _currentLevelIndex++;
    final level = LevelLoader.generateLevel(_currentLevelIndex, mode);
    _state = GameState(
      level: level,
      pendingScore: savedPendingScore,
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
