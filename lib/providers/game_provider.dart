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

  Timer? _shakeTimer;
  Timer? _lastFoundTimer;

  Future<void> startGame(LanguageMode mode, {int levelNumber = 1}) async {
    final level = LevelLoader.generateLevel(levelNumber, mode);
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

    final unfound = s.level.targetWords.cast<TargetWord?>().firstWhere(
          (w) => !w!.isFound && !w.isBonus,
          orElse: () => null,
        );
    if (unfound == null) return;

    final hintLetter = unfound.word[0];
    final hintTile =
        s.level.sourceLetters.cast<LetterTile?>().firstWhere(
              (t) => t!.letter == hintLetter && !t.isSelected,
              orElse: () => null,
            );
    if (hintTile == null) return;

    final newSelected = [...s.selectedTileIds, hintTile.id];
    final newInput = newSelected
        .map((id) =>
            s.level.sourceLetters.firstWhere((t) => t.id == id).letter)
        .join();

    _state = s.copyWith(
      hintsRemaining: s.hintsRemaining - 1,
      selectedTileIds: newSelected,
      currentInput: newInput,
      level: s.level.copyWith(
        sourceLetters: s.level.sourceLetters
            .map((t) =>
                t.id == hintTile.id ? t.copyWith(isSelected: true) : t)
            .toList(),
      ),
    );
    notifyListeners();
  }

  void nextLevel(LanguageMode mode) {
    final savedScore = _state!.score;
    final savedHints = _state!.hintsRemaining;
    final nextLevelNum = _state!.level.id + 1;
    final level = LevelLoader.generateLevel(nextLevelNum, mode);
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
    super.dispose();
  }
}
