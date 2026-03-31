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

  const TargetWord({
    required this.word,
    required this.length,
    this.isFound = false,
    this.isBonus = false,
  });

  TargetWord copyWith({bool? isFound}) => TargetWord(
        word: word,
        length: length,
        isFound: isFound ?? this.isFound,
        isBonus: isBonus,
      );
}

class GameLevel {
  final int id;
  final String sourceWord;
  final List<LetterTile> sourceLetters;
  final List<TargetWord> targetWords;
  final int totalWords;

  const GameLevel({
    required this.id,
    required this.sourceWord,
    required this.sourceLetters,
    required this.targetWords,
    required this.totalWords,
  });

  GameLevel copyWith({
    List<LetterTile>? sourceLetters,
    List<TargetWord>? targetWords,
  }) =>
      GameLevel(
        id: id,
        sourceWord: sourceWord,
        sourceLetters: sourceLetters ?? this.sourceLetters,
        targetWords: targetWords ?? this.targetWords,
        totalWords: totalWords,
      );
}

enum WordValidationResult { found, alreadyFound, bonus, invalid }

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
      );
}
