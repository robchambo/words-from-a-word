import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../models/language_mode.dart';
import '../engine/game_engine.dart';
import '../engine/level_loader.dart';
import '../services/achievement_engine.dart';
import '../services/ad_gateway.dart';
import '../services/audio_service.dart';
import 'rewards_provider.dart';

class GameProvider extends ChangeNotifier {
  GameProvider({
    required RewardsProvider rewards,
    required AdGateway adGateway,
    Random? rng,
  })  : _rewards = rewards,
        _adGateway = adGateway,
        _rng = rng ?? Random();

  final RewardsProvider _rewards;
  final AdGateway _adGateway;
  final Random _rng;

  AchievementEngine? _achievements;

  void attachAchievementEngine(AchievementEngine e) {
    _achievements = e;
  }

  GameState? _state;
  GameState get state => _state!;
  bool get isReady => _state != null;

  int _currentLevelIndex = 1; // Global 1-based position in the level array.
  LanguageMode? _mode; // Tracks the current language mode for achievement events.

  Timer? _shakeTimer;
  Timer? _lastFoundTimer;
  Timer? _tooCommonTimer;
  Timer? _alreadyUsedTimer;

  Map<String, Set<int>> get _revealedPositionsSnapshot => {
        for (final tw in _state!.level.targetWords) tw.word: tw.revealedIndices,
      };

  bool get hintAvailable {
    if (_state == null) return false;
    // A hint is available only if a safe position exists in the level.
    // Capacity (free slot / purchased / rewarded-ad fallback) is handled when
    // consumed; the button is enabled whenever there's somewhere to hint.
    return GameEngine.pickSafeHintLetter(
          targetWords: _state!.level.targetWords,
          revealedPositions: _revealedPositionsSnapshot,
          rng: Random(0),
        ) !=
        null;
  }

  Future<void> startGame(
    LanguageMode mode, {
    int levelNumber = 1,
    bool isReplay = false,
  }) async {
    _mode = mode;
    _currentLevelIndex = levelNumber;
    final level = LevelLoader.generateLevel(_currentLevelIndex, mode);
    _rewards.maybeRefillDailyHint();

    final isReplayOfCompleted = isReplay &&
        (_rewards.highestCompletedLevel[mode] ?? 0) >= levelNumber;

    List<TargetWord> initialTargets = level.targetWords;
    List<String> initialFound = const [];
    if (isReplayOfCompleted) {
      // All REQUIRED words count as found. Any bonuses already banked for this
      // level also count as found (uniqueness blocks re-submission).
      final bankedHere =
          _rewards.bankedBonusWords[mode]?[levelNumber] ?? <String>{};
      initialTargets = level.targetWords.map((tw) {
        final shouldPreFill = !tw.isBonus || bankedHere.contains(tw.word);
        return shouldPreFill ? tw.copyWith(isFound: true) : tw;
      }).toList();
      initialFound = initialTargets
          .where((tw) => tw.isFound)
          .map((tw) => tw.word)
          .toList();
    }

    _state = GameState(
      level: level.copyWith(targetWords: initialTargets),
      isReplayMode: isReplay,
      foundWords: initialFound,
      isLevelComplete:
          isReplayOfCompleted ? GameEngine.isLevelComplete(initialTargets) : false,
    );
    notifyListeners();
  }

  void selectTile(String tileId) {
    final s = _state!;
    final tile = s.level.sourceLetters.firstWhere((t) => t.id == tileId);
    if (tile.isUsed || tile.isSelected) return;

    HapticFeedback.selectionClick();
    audioService.playTap();

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
      bankedBonusesInLanguage: _bankedBonusSetForCurrentMode(),
    );

    if (result == WordValidationResult.invalid ||
        result == WordValidationResult.alreadyFound) {
      HapticFeedback.heavyImpact();
      audioService.playError();
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

    if (result == WordValidationResult.alreadyUsedElsewhere) {
      HapticFeedback.lightImpact();
      final level = _rewards.bankedBonusLevel(
        mode: _mode!, word: word,
      );
      _state = s.copyWith(
        selectedTileIds: [],
        currentInput: '',
        alreadyUsedWord: word,
        alreadyUsedInLevel: level,
        level: s.level.copyWith(
          sourceLetters: s.level.sourceLetters
              .map((t) => t.copyWith(isSelected: false))
              .toList(),
        ),
      );
      notifyListeners();
      _alreadyUsedTimer?.cancel();
      _alreadyUsedTimer = Timer(const Duration(milliseconds: 2000), () {
        _state = _state!.copyWith(clearAlreadyUsedWord: true);
        notifyListeners();
      });
      return;
    }

    HapticFeedback.mediumImpact();
    audioService.playSuccess();

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

    if (levelDone) {
      HapticFeedback.heavyImpact();
      audioService.playLevelComplete();
    }

    _achievements?.onWordFound(
      mode: _mode ?? LanguageMode.russian,
      wordLength: word.length,
      isBonus: foundTarget.isBonus,
      isReplay: s.isReplayMode,
    );

    // Replay-of-completed: bank bonuses immediately because bankAndAdvance will
    // be a no-op for replays. pendingScore is still updated for UI consistency,
    // but lifetime score is credited live.
    final isReplayOfCompleted = s.isReplayMode &&
        (_rewards.highestCompletedLevel[_mode!] ?? 0) >= _currentLevelIndex;
    if (isReplayOfCompleted && foundTarget.isBonus) {
      final newlyBanked = _rewards.bankBonusWords(
        mode: _mode!,
        levelId: _currentLevelIndex,
        words: [word],
      );
      if (newlyBanked > 0) {
        _rewards.incrementBonusCounter();
        _rewards.addLifetimeScore(mode: _mode!, points: points);
      }
    }

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
    if (_state == null) return;
    final safe = GameEngine.pickSafeHintLetter(
      targetWords: _state!.level.targetWords,
      revealedPositions: _revealedPositionsSnapshot,
      rng: _rng,
    );
    if (safe == null) return;

    final source = _rewards.consumeHint();
    if (source == null) {
      // No free/purchased hint available — surface the rewarded-ad prompt.
      _state = _state!.copyWith(pendingRewardedAdPrompt: true);
      notifyListeners();
      return;
    }

    _applyReveal(safe);
  }

  void _applyReveal(SafeHintResult safe) {
    final s = _state!;
    // Find the tile id whose letter+position matches the reveal.
    // revealedIndices on TargetWord tracks word-local positions, but the UI
    // highlights source tiles via GameState.revealedTileIds (set of tile ids).
    // We update BOTH: the TargetWord indices (used by WordSlotItem underline)
    // AND revealedTileIds (used by tile_picker's isHinted visual).
    final updatedTargetWords = s.level.targetWords.map((tw) {
      if (tw.word != safe.wordKey) return tw;
      final newIndices = {...tw.revealedIndices, safe.position};
      return tw.copyWith(revealedIndices: newIndices);
    }).toList();

    // Add one matching tile id to revealedTileIds — prefer a tile whose letter
    // matches and isn't already in the set. If we can't find one, leave the
    // set unchanged (word-slot underline still fires).
    final newRevealedTileIds = Set<String>.from(s.revealedTileIds);
    for (final tile in s.level.sourceLetters) {
      if (tile.letter == safe.letter && !newRevealedTileIds.contains(tile.id)) {
        newRevealedTileIds.add(tile.id);
        break;
      }
    }

    _state = s.copyWith(
      level: s.level.copyWith(targetWords: updatedTargetWords),
      revealedTileIds: newRevealedTileIds,
    );
    HapticFeedback.lightImpact();
    audioService.playHintReveal();
    notifyListeners();
  }

  /// Called by GameScreen after a rewarded ad completes (Phase 5 wires the ad).
  void onRewardedAdCompleted() {
    if (_state == null) return;
    _state = _state!.copyWith(pendingRewardedAdPrompt: false);
    final safe = GameEngine.pickSafeHintLetter(
      targetWords: _state!.level.targetWords,
      revealedPositions: _revealedPositionsSnapshot,
      rng: _rng,
    );
    if (safe == null) {
      notifyListeners();
      return;
    }
    _rewards.addPurchasedHints(1);
    _rewards.consumeHint(); // should now return HintSource.purchased
    _applyReveal(safe);
  }

  void onRewardedAdDeclined() {
    if (_state == null) return;
    _state = _state!.copyWith(pendingRewardedAdPrompt: false);
    notifyListeners();
  }

  /// Commits pendingScore + best score for the current level and advances
  /// the level index. Requires `state.isLevelComplete` — abandons are handled
  /// by the next `startGame` implicitly discarding pendingScore.
  Future<void> bankAndAdvance(LanguageMode mode) async {
    if (_state == null || !_state!.isLevelComplete) return;

    final usedHint = _state!.revealedTileIds.isNotEmpty ||
        _state!.level.targetWords.any((tw) => tw.revealedIndices.isNotEmpty);
    final bonusWords =
        _state!.level.targetWords.where((tw) => tw.isBonus).toList();
    final foundAllBonus =
        bonusWords.isNotEmpty && bonusWords.every((tw) => tw.isFound);

    _achievements?.onLevelComplete(
      mode: mode,
      levelId: _currentLevelIndex,
      usedHint: usedHint,
      foundAllBonus: foundAllBonus,
      isReplay: _state!.isReplayMode,
    );

    _rewards.onLevelComplete(
      mode: mode,
      levelId: _currentLevelIndex,
      pendingScore: _state!.pendingScore,
      isReplay: _state!.isReplayMode,
    );

    // Bank all provisional bonuses (found this session in the just-completed
    // level). Hint counter increments once per newly-banked bonus.
    if (!_state!.isReplayMode) {
      final provisionalBonuses = _state!.level.targetWords
          .where((tw) => tw.isBonus && tw.isFound)
          .map((tw) => tw.word)
          .toList();
      if (provisionalBonuses.isNotEmpty) {
        final newlyBanked = _rewards.bankBonusWords(
          mode: mode,
          levelId: _currentLevelIndex,
          words: provisionalBonuses,
        );
        for (var i = 0; i < newlyBanked; i++) {
          _rewards.incrementBonusCounter();
        }
      }
    }

    if (!_rewards.premium) {
      await _adGateway.showInterstitial();
    }
    // nextLevel is now called separately by the caller so LibraryCompleteScreen
    // (Phase 3) can interpose.
  }

  void nextLevel(LanguageMode mode) {
    _mode = mode;
    _currentLevelIndex++;
    try {
      final level = LevelLoader.generateLevel(_currentLevelIndex, mode);
      _state = GameState(level: level);
      _rewards.maybeRefillDailyHint();
    } on LevelNotFoundException {
      // No more levels in the library — revert the index increment and signal
      // library completion so the UI can route to the library-complete screen.
      _currentLevelIndex--;
      _state = _state!.copyWith(libraryComplete: true);
    }
    notifyListeners();
  }

  Set<String> _bankedBonusSetForCurrentMode() {
    final map = _rewards.bankedBonusWords[_mode!]!;
    final out = <String>{};
    for (final set in map.values) {
      out.addAll(set);
    }
    return out;
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _lastFoundTimer?.cancel();
    _tooCommonTimer?.cancel();
    _alreadyUsedTimer?.cancel();
    super.dispose();
  }
}
