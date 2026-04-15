enum LevelDifficulty { beginner, easy, medium, hard, expert }

class LetterTile {
  final String id;
  final String letter;
  final bool isSelected;
  final bool isUsed;

  const LetterTile({
    required this.id,
    required this.letter,
    this.isSelected = false,
    this.isUsed = false,
  });

  LetterTile copyWith({bool? isSelected, bool? isUsed}) => LetterTile(
        id: id,
        letter: letter,
        isSelected: isSelected ?? this.isSelected,
        isUsed: isUsed ?? this.isUsed,
      );
}

class TargetWord {
  final String word;
  final int length;
  final bool isFound;
  final bool isBonus;
  final Set<int> revealedIndices;

  const TargetWord({
    required this.word,
    required this.length,
    this.isFound = false,
    this.isBonus = false,
    this.revealedIndices = const {},
  });

  TargetWord copyWith({bool? isFound, Set<int>? revealedIndices}) => TargetWord(
        word: word,
        length: length,
        isFound: isFound ?? this.isFound,
        isBonus: isBonus,
        revealedIndices: revealedIndices ?? this.revealedIndices,
      );
}

class GameLevel {
  final int levelNumber;  // Within-difficulty position (1-based); shown in the stamp.
  final String sourceWord;
  final List<LetterTile> sourceLetters;
  final List<TargetWord> targetWords;
  final List<String> tooCommon;
  final int totalWords;
  final LevelDifficulty difficulty;

  const GameLevel({
    required this.levelNumber,
    required this.sourceWord,
    required this.sourceLetters,
    required this.targetWords,
    required this.totalWords,
    this.tooCommon = const [],
    this.difficulty = LevelDifficulty.easy,
  });

  GameLevel copyWith({
    List<LetterTile>? sourceLetters,
    List<TargetWord>? targetWords,
  }) =>
      GameLevel(
        levelNumber: levelNumber,
        sourceWord: sourceWord,
        sourceLetters: sourceLetters ?? this.sourceLetters,
        targetWords: targetWords ?? this.targetWords,
        totalWords: totalWords,
        tooCommon: tooCommon,
        difficulty: difficulty,
      );
}

enum WordValidationResult { found, alreadyFound, bonus, tooCommon, invalid }

class GameState {
  final GameLevel level;
  final List<String> selectedTileIds;
  final String currentInput;
  final List<String> foundWords;
  final int score;
  final int hintsRemaining;
  final bool isShaking;
  final bool isLevelComplete;
  final String? lastFoundWord;
  final String? tooCommonWord;

  final Map<String, int> hintedLetterCounts;

  const GameState({
    required this.level,
    this.selectedTileIds = const [],
    this.currentInput = '',
    this.foundWords = const [],
    this.score = 0,
    this.hintsRemaining = 3,
    this.isShaking = false,
    this.isLevelComplete = false,
    this.lastFoundWord,
    this.tooCommonWord,
    this.hintedLetterCounts = const {},
  });

  GameState copyWith({
    GameLevel? level,
    List<String>? selectedTileIds,
    String? currentInput,
    List<String>? foundWords,
    int? score,
    int? hintsRemaining,
    bool? isShaking,
    bool? isLevelComplete,
    String? lastFoundWord,
    bool clearLastFoundWord = false,
    String? tooCommonWord,
    bool clearTooCommonWord = false,
    Map<String, int>? hintedLetterCounts,
  }) =>
      GameState(
        level: level ?? this.level,
        selectedTileIds: selectedTileIds ?? this.selectedTileIds,
        currentInput: currentInput ?? this.currentInput,
        foundWords: foundWords ?? this.foundWords,
        score: score ?? this.score,
        hintsRemaining: hintsRemaining ?? this.hintsRemaining,
        isShaking: isShaking ?? this.isShaking,
        isLevelComplete: isLevelComplete ?? this.isLevelComplete,
        lastFoundWord:
            clearLastFoundWord ? null : (lastFoundWord ?? this.lastFoundWord),
        tooCommonWord:
            clearTooCommonWord ? null : (tooCommonWord ?? this.tooCommonWord),
        hintedLetterCounts: hintedLetterCounts ?? this.hintedLetterCounts,
      );
}
