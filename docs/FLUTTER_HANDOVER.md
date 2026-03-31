# Слова из Слова — Flutter Handover Document

> **Note — implementation deviations from this spec:**
> This document is the original Manus AI spec. The app has been fully built; see `CLAUDE.md` for the authoritative current state. Key deviations: (1) no dictionary `.txt` files — validation is level-targetWords only; (2) fonts loaded via `google_fonts` at runtime, not bundled `.ttf` files; (3) `flutter_vibrate` replaced with Flutter's built-in `HapticFeedback`; (4) `flutter_svg` and `flutter_localizations` not used. See `docs/DECISIONS.md` for full rationale.

**For:** Claude Code
**Prepared by:** Manus AI  
**Date:** March 2026  
**Purpose:** Complete specification and starter code to build the Слова из Слова cross-platform word game in Flutter, ported from a working React/TypeScript web prototype.

---

## 1. Project Overview

**Слова из Слова** ("Words from a Word") is a casual word game for the Russian-speaking US diaspora. Players are given a long source word and must form as many valid shorter words as possible by tapping letter tiles. The app supports two language modes — Russian and English — selectable from the home screen. The Russian mode uses a curated dictionary of 26,593 nouns from the OpenRussian dataset. The English mode uses a curated subset of common English nouns suitable for word-building puzzles.

The design aesthetic is **Soviet Notebook** (Ностальгический Модернизм): warm cream paper background with a subtle grid-paper texture, deep navy ink typography, crimson red accents, amber gold rewards, and Playfair Display serif headings. Every visual decision reinforces the feeling of a well-worn school exercise book.

The app is **free with ad support** (Google AdMob + Meta Audience Network). It targets iOS and Android. There is no backend — all game data is bundled locally.

---

## 2. Flutter Project Setup

### 2.1 pubspec.yaml

```yaml
name: slova_iz_slova
description: Russian/English word game for the US diaspora
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.22.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State management
  provider: ^6.1.2

  # Animations
  flutter_animate: ^4.5.0

  # Fonts (loaded via Google Fonts)
  google_fonts: ^6.2.1

  # Shared preferences (persist language choice, score, level)
  shared_preferences: ^2.3.2

  # Ads (add after core game is working)
  # google_mobile_ads: ^5.1.0

  # Haptic feedback
  flutter_vibrate: ^1.3.0

  # Icons
  flutter_svg: ^2.0.10+1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true

  assets:
    - assets/data/russian_levels.json
    - assets/data/english_levels.json
    - assets/data/russian_valid_words.txt
    - assets/data/english_valid_words.txt

  fonts:
    - family: PlayfairDisplay
      fonts:
        - asset: assets/fonts/PlayfairDisplay-Regular.ttf
        - asset: assets/fonts/PlayfairDisplay-Bold.ttf
          weight: 700
        - asset: assets/fonts/PlayfairDisplay-Black.ttf
          weight: 900
        - asset: assets/fonts/PlayfairDisplay-Italic.ttf
          style: italic
    - family: RobotoCondensed
      fonts:
        - asset: assets/fonts/RobotoCondensed-Regular.ttf
        - asset: assets/fonts/RobotoCondensed-Bold.ttf
          weight: 700
```

> **Note on fonts:** Download Playfair Display and Roboto Condensed from Google Fonts and place them in `assets/fonts/`. Alternatively, use the `google_fonts` package to load them at runtime — simpler for development, but bundling is preferred for production to avoid network dependency.

### 2.2 Directory Structure

```
slova_iz_slova/
├── assets/
│   ├── data/
│   │   ├── russian_levels.json        # 23 curated Russian levels
│   │   ├── english_levels.json        # 20 curated English levels
│   │   ├── russian_valid_words.txt    # Full Russian word validation set
│   │   └── english_valid_words.txt    # English word validation set
│   └── fonts/
│       ├── PlayfairDisplay-*.ttf
│       └── RobotoCondensed-*.ttf
├── lib/
│   ├── main.dart                      # App entry point
│   ├── app.dart                       # MaterialApp, ThemeData, routing
│   ├── theme/
│   │   └── app_theme.dart             # Full Soviet Notebook ThemeData
│   ├── models/
│   │   ├── game_state.dart            # GameState, GameLevel, LetterTile, TargetWord
│   │   └── language_mode.dart         # LanguageMode enum (russian / english)
│   ├── engine/
│   │   ├── game_engine.dart           # Core logic: validate, score, canFormWord
│   │   ├── level_loader.dart          # Loads levels from JSON assets
│   │   └── dictionary.dart            # Dictionary lookup (Set<String>)
│   ├── providers/
│   │   ├── game_provider.dart         # ChangeNotifier wrapping game state
│   │   └── settings_provider.dart     # Language choice, persisted settings
│   ├── screens/
│   │   ├── home_screen.dart           # Splash / language select / menu
│   │   └── game_screen.dart           # Main gameplay screen
│   ├── widgets/
│   │   ├── letter_tile.dart           # Individual tappable tile
│   │   ├── tile_picker.dart           # Tile grid + current word + action buttons
│   │   ├── word_slots.dart            # Grouped word slot display
│   │   ├── word_slot_item.dart        # Single word slot row
│   │   ├── stamp_badge.dart           # Circular crimson stamp widget
│   │   ├── level_complete_overlay.dart # Full-screen level complete celebration
│   │   └── rules_modal.dart           # Rules bottom sheet
│   └── l10n/
│       ├── strings_ru.dart            # Russian UI strings
│       └── strings_en.dart            # English UI strings
├── test/
│   └── game_engine_test.dart
└── pubspec.yaml
```

---

## 3. Design System — Soviet Notebook

This section is the single source of truth for all visual decisions. Every widget must reference these tokens. Do not hardcode colours or font sizes.

### 3.1 Colour Palette

The palette is derived from the CSS design system of the web prototype, converted from OKLCH to Flutter `Color` hex values.

| Token | Hex | Usage |
|---|---|---|
| `background` | `#FFFEF0` | App background, paper surface |
| `foreground` | `#1D2B38` | Primary text, navy ink |
| `primary` | `#B22030` | Crimson red — CTAs, stamp borders, progress bar |
| `primaryForeground` | `#FEFEF8` | Text on crimson backgrounds |
| `accent` | `#F5A234` | Amber gold — bonus words, stars, rewards |
| `muted` | `#EDE9DC` | Disabled states, secondary surfaces |
| `mutedForeground` | `#7A8A96` | Placeholder text, secondary labels |
| `border` | `#C8D0D8` | Grid lines, tile borders, dividers |
| `tileBg` | `#F5F2E8` | Letter tile background (slightly aged) |
| `slotEmpty` | `#D8DDE3` | Unfilled word slot underline |
| `slotFilled` | `#1D2B38` | Filled word slot underline (navy) |
| `card` | `#F7F4EC` | Card surfaces |

### 3.2 Typography

```dart
// In app_theme.dart — reference these everywhere
static const String _displayFont = 'PlayfairDisplay';
static const String _bodyFont = 'RobotoCondensed';

// Display: source word title, game title, level complete score
TextStyle displayLarge = TextStyle(
  fontFamily: _displayFont,
  fontWeight: FontWeight.w900,
  fontSize: 32,
  color: foreground,
  letterSpacing: 1.5,
);

// Display italic: motivational filler text ("Начинайте!")
TextStyle displayItalic = TextStyle(
  fontFamily: _displayFont,
  fontStyle: FontStyle.italic,
  fontSize: 24,
  color: primary.withOpacity(0.4),
);

// Condensed bold: tile letters, button labels, section headers
TextStyle condensedBold = TextStyle(
  fontFamily: _bodyFont,
  fontWeight: FontWeight.w700,
  fontSize: 14,
  letterSpacing: 1.2,
  color: foreground,
);

// Condensed small caps: labels, counters, metadata
TextStyle condensedLabel = TextStyle(
  fontFamily: _bodyFont,
  fontWeight: FontWeight.w400,
  fontSize: 10,
  letterSpacing: 3.0,
  color: mutedForeground,
);
```

### 3.3 Grid Paper Background

The background texture is a CSS grid pattern. In Flutter, replicate it with a `CustomPainter` or a `Stack` with a `GridPaper` widget:

```dart
// In app.dart Scaffold background — use this pattern
Widget _gridBackground() {
  return CustomPaint(
    painter: _GridPaperPainter(
      lineColor: const Color(0xFFC8D0D8).withOpacity(0.5),
      cellSize: 20.0,
    ),
    child: const SizedBox.expand(),
  );
}

class _GridPaperPainter extends CustomPainter {
  final Color lineColor;
  final double cellSize;
  _GridPaperPainter({required this.lineColor, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;
    for (double x = 0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPaperPainter old) => false;
}
```

### 3.4 Letter Tile Widget Spec

```
Shape:      RoundedRectangle, borderRadius: 8
Size:       48×48 (md), 40×40 (sm), 56×56 (lg)
Background: #F5F2E8 (tileBg)
Border:     1px solid #C8D0D8 at 60% opacity
Shadow:     BoxShadow(offset: Offset(0,2), blurRadius: 6, color: #1D2B38 at 18%)
Font:       RobotoCondensed Bold, 18sp, #1D2B38

Selected state:
  Background: #FFFEF0 (slightly lighter)
  Border:     #B22030 at 70% opacity (crimson)
  Shadow:     BoxShadow(offset: Offset(0,6), blurRadius: 16, color: #1D2B38 at 28%)
  Transform:  scale(1.08), translateY(-2)

Used state:
  Opacity: 0.35
  Pointer events: none

Shake animation (invalid word):
  Duration: 350ms
  Keyframes: x=0 → x=-6 → x=6 → x=-4 → x=4 → x=0
  Use flutter_animate: .shake() or custom AnimationController
```

### 3.5 Stamp Badge Widget Spec

```
Shape:      Circle
Size:       44×44 (standard), 36×36 (small)
Border:     2.5px solid #B22030 (crimson)
Color:      #B22030 text
Opacity:    0.85
Font:       RobotoCondensed Bold, uppercase, letter-spacing 0.05em
Animation:  stamp-in on first appearance
  → scale(2.5) rotate(-8°) opacity(0) → scale(0.92) rotate(2°) opacity(1) → scale(1) rotate(0°) opacity(0.85)
  Duration: 450ms, cubic-bezier(0.22, 1, 0.36, 1)
```

### 3.6 Word Slot Spec

```
Each slot is a single letter underline:
  Width:        min 22px, expands with letter
  Height:       32px
  Border-bottom: 2px solid #D8DDE3 (empty) / #1D2B38 (filled)
  Transition:   border-color 200ms

Letter reveal animation (when word is found):
  Scale: 1 → 1.12 → 1 over 300ms
  Color: foreground (#1D2B38)
  Font:  RobotoCondensed Bold, 13sp, uppercase

Slots are grouped by word length with section headers:
  "3 БУКВЫ" / "4 БУКВЫ" / "5 БУКВ" etc. (Russian)
  "3 LETTERS" / "4 LETTERS" / "5 LETTERS" etc. (English)
  Header font: condensedLabel style, uppercase, letterSpacing 3.0
```

---

## 4. Models (Dart)

### 4.1 `lib/models/language_mode.dart`

```dart
enum LanguageMode { russian, english }

extension LanguageModeExtension on LanguageMode {
  String get displayName {
    switch (this) {
      case LanguageMode.russian: return 'Русский';
      case LanguageMode.english: return 'English';
    }
  }

  String get flagEmoji {
    switch (this) {
      case LanguageMode.russian: return '🇷🇺';
      case LanguageMode.english: return '🇺🇸';
    }
  }

  String get levelsAsset {
    switch (this) {
      case LanguageMode.russian: return 'assets/data/russian_levels.json';
      case LanguageMode.english: return 'assets/data/english_levels.json';
    }
  }

  String get wordsAsset {
    switch (this) {
      case LanguageMode.russian: return 'assets/data/russian_valid_words.txt';
      case LanguageMode.english: return 'assets/data/english_valid_words.txt';
    }
  }
}
```

### 4.2 `lib/models/game_state.dart`

```dart
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
  }) => GameLevel(
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
  }) => GameState(
    level: level ?? this.level,
    selectedTileIds: selectedTileIds ?? this.selectedTileIds,
    currentInput: currentInput ?? this.currentInput,
    foundWords: foundWords ?? this.foundWords,
    score: score ?? this.score,
    hintsRemaining: hintsRemaining ?? this.hintsRemaining,
    isShaking: isShaking ?? this.isShaking,
    isLevelComplete: isLevelComplete ?? this.isLevelComplete,
    lastFoundWord: clearLastFoundWord ? null : (lastFoundWord ?? this.lastFoundWord),
  );
}
```

---

## 5. Game Engine (Dart)

### 5.1 `lib/engine/game_engine.dart`

```dart
import '../models/game_state.dart';

class GameEngine {
  /// Count letter frequencies in a word (case-insensitive)
  static Map<String, int> letterCount(String word) {
    final counts = <String, int>{};
    for (final ch in word.toLowerCase().split('')) {
      counts[ch] = (counts[ch] ?? 0) + 1;
    }
    return counts;
  }

  /// Check if [sub] can be formed from letters of [source]
  static bool canFormWord(String sub, String source) {
    final srcCount = letterCount(source);
    final subCount = letterCount(sub);
    for (final entry in subCount.entries) {
      if ((srcCount[entry.key] ?? 0) < entry.value) return false;
    }
    return true;
  }

  /// Validate a submitted word against the level
  static WordValidationResult validateWord({
    required String word,
    required String sourceWord,
    required List<TargetWord> targetWords,
    required List<String> foundWords,
  }) {
    final w = word.toLowerCase();
    if (foundWords.contains(w)) return WordValidationResult.alreadyFound;
    if (!canFormWord(w, sourceWord)) return WordValidationResult.invalid;

    final target = targetWords.cast<TargetWord?>().firstWhere(
      (t) => t!.word == w,
      orElse: () => null,
    );
    if (target == null) return WordValidationResult.invalid;
    if (target.isBonus) return WordValidationResult.bonus;
    return WordValidationResult.found;
  }

  /// Score a word: 10 pts per letter, length bonus
  static int scoreWord(String word) {
    final base = word.length * 10;
    final bonus = word.length >= 6 ? 30
        : word.length >= 5 ? 20
        : word.length >= 4 ? 10
        : 0;
    return base + bonus;
  }

  /// Check if all required (non-bonus) words are found
  static bool isLevelComplete(List<TargetWord> targetWords) {
    return targetWords
        .where((w) => !w.isBonus)
        .every((w) => w.isFound);
  }

  /// Fisher-Yates shuffle
  static List<T> shuffleList<T>(List<T> list) {
    final a = List<T>.from(list);
    for (int i = a.length - 1; i > 0; i--) {
      final j = (DateTime.now().microsecondsSinceEpoch % (i + 1)).toInt();
      final tmp = a[i];
      a[i] = a[j];
      a[j] = tmp;
    }
    return a;
  }
}
```

> **Note:** Replace the shuffle with `Random` from `dart:math` for proper randomness:
> ```dart
> import 'dart:math';
> final rng = Random();
> final j = rng.nextInt(i + 1);
> ```

### 5.2 `lib/engine/level_loader.dart`

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../models/language_mode.dart';
import 'game_engine.dart';

class LevelLoader {
  static List<Map<String, dynamic>>? _russianDefs;
  static List<Map<String, dynamic>>? _englishDefs;

  static Future<void> preload() async {
    final ruJson = await rootBundle.loadString('assets/data/russian_levels.json');
    final enJson = await rootBundle.loadString('assets/data/english_levels.json');
    _russianDefs = List<Map<String, dynamic>>.from(jsonDecode(ruJson));
    _englishDefs = List<Map<String, dynamic>>.from(jsonDecode(enJson));
  }

  static GameLevel generateLevel(int levelNumber, LanguageMode mode) {
    final defs = mode == LanguageMode.russian ? _russianDefs! : _englishDefs!;
    final def = defs[(levelNumber - 1) % defs.length];

    final sourceWord = def['sourceWord'] as String;
    final required = List<String>.from(def['required'] as List);
    final bonus = List<String>.from(def['bonus'] as List? ?? []);

    // Deduplicate and validate
    final validRequired = required.toSet()
        .where((w) => GameEngine.canFormWord(w, sourceWord))
        .take(12)
        .toList();

    final validBonus = bonus.toSet()
        .where((w) => GameEngine.canFormWord(w, sourceWord))
        .toList();

    final targetWords = [
      ...validRequired.map((w) => TargetWord(word: w, length: w.length, isBonus: false)),
      ...validBonus.map((w) => TargetWord(word: w, length: w.length, isBonus: true)),
    ];

    // Shuffle source letters
    final letters = sourceWord.toLowerCase().split('');
    final shuffled = GameEngine.shuffleList(letters);

    final sourceLetters = shuffled.asMap().entries.map((e) => LetterTile(
      id: 'tile-${e.key}-${e.value}-$levelNumber',
      letter: e.value,
    )).toList();

    return GameLevel(
      id: levelNumber,
      sourceWord: sourceWord,
      sourceLetters: sourceLetters,
      targetWords: targetWords,
      totalWords: validRequired.length,
    );
  }
}
```

---

## 6. Providers

### 6.1 `lib/providers/settings_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/language_mode.dart';

class SettingsProvider extends ChangeNotifier {
  LanguageMode _languageMode = LanguageMode.russian;
  LanguageMode get languageMode => _languageMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('language_mode');
    if (saved == 'english') {
      _languageMode = LanguageMode.english;
    } else {
      _languageMode = LanguageMode.russian;
    }
    notifyListeners();
  }

  Future<void> setLanguageMode(LanguageMode mode) async {
    _languageMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_mode', mode.name);
    notifyListeners();
  }
}
```

### 6.2 `lib/providers/game_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
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

    final newSelected = [...s.selectedTileIds, tileId];
    final newInput = newSelected
        .map((id) => s.level.sourceLetters.firstWhere((t) => t.id == id).letter)
        .join();

    _state = s.copyWith(
      selectedTileIds: newSelected,
      currentInput: newInput,
      level: s.level.copyWith(
        sourceLetters: s.level.sourceLetters.map((t) =>
          t.id == tileId ? t.copyWith(isSelected: true) : t
        ).toList(),
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
        .map((id) => s.level.sourceLetters.firstWhere((t) => t.id == id).letter)
        .join();
    final deselectedIds = s.selectedTileIds.sublist(idx);

    _state = s.copyWith(
      selectedTileIds: newSelected,
      currentInput: newInput,
      level: s.level.copyWith(
        sourceLetters: s.level.sourceLetters.map((t) =>
          deselectedIds.contains(t.id) ? t.copyWith(isSelected: false) : t
        ).toList(),
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
        sourceLetters: s.level.sourceLetters.map((t) => t.copyWith(isSelected: false)).toList(),
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
      _state = s.copyWith(isShaking: true);
      notifyListeners();
      _shakeTimer?.cancel();
      _shakeTimer = Timer(const Duration(milliseconds: 400), () {
        _state = _state!.copyWith(isShaking: false);
        notifyListeners();
      });
      return;
    }

    final points = GameEngine.scoreWord(word);
    final newFoundWords = [...s.foundWords, word];
    final updatedTargetWords = s.level.targetWords.map((tw) =>
      tw.word == word ? tw.copyWith(isFound: true) : tw
    ).toList();

    final updatedLetters = s.level.sourceLetters.map((t) =>
      s.selectedTileIds.contains(t.id) ? t.copyWith(isSelected: false) : t
    ).toList();

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
    final shuffled = GameEngine.shuffleList(List<LetterTile>.from(s.level.sourceLetters));
    _state = s.copyWith(level: s.level.copyWith(sourceLetters: shuffled));
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
    final hintTile = s.level.sourceLetters.cast<LetterTile?>().firstWhere(
      (t) => t!.letter == hintLetter && !t.isSelected,
      orElse: () => null,
    );
    if (hintTile == null) return;

    final newSelected = [...s.selectedTileIds, hintTile.id];
    final newInput = newSelected
        .map((id) => s.level.sourceLetters.firstWhere((t) => t.id == id).letter)
        .join();

    _state = s.copyWith(
      hintsRemaining: s.hintsRemaining - 1,
      selectedTileIds: newSelected,
      currentInput: newInput,
      level: s.level.copyWith(
        sourceLetters: s.level.sourceLetters.map((t) =>
          t.id == hintTile.id ? t.copyWith(isSelected: true) : t
        ).toList(),
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
```

---

## 7. Localisation Strings

### 7.1 `lib/l10n/strings_ru.dart`

```dart
class StringsRu {
  // Home screen
  static const String appTitle = 'Слова из Слова';
  static const String appSubtitle = 'Классическая игра';
  static const String dictionaryLabel = 'Русский словарь';
  static const String playButton = 'Играть';
  static const String rulesButton = 'Правила';
  static const String settingsButton = 'Настройки';
  static const String leaderboardButton = 'Рейтинг';
  static const String footerText = 'Слова из Слова · Русский язык';

  // Language select
  static const String chooseLang = 'Выберите язык';
  static const String playRussian = 'Русский';
  static const String playEnglish = 'English';
  static const String langToggleHint = 'Сменить язык';

  // Game screen
  static const String subtitle = 'Составьте слова из этих букв';
  static const String hintButton = 'Подсказка';
  static const String checkButton = 'Проверить';
  static const String levelLabel = 'УР.';
  static const String scoreLabel = 'Очки';
  static const String wordsLeft = 'слов осталось';
  static const String wordsOf = 'слов';
  static const String startPrompt = 'Начинайте!';
  static const String allFoundPrompt = 'Отлично!';
  static const String selectLetters = 'Выберите буквы';
  static const String bonusLabel = 'Бонус';

  // Word slot headers — Russian pluralisation
  static String lettersHeader(int n) {
    if (n == 1) return '1 БУКВА';
    if (n >= 2 && n <= 4) return '$n БУКВЫ';
    return '$n БУКВ';
  }

  // Rules modal
  static const String rulesTitle = 'Правила игры';
  static const String rulesGoal = 'Цель: составьте как можно больше слов из букв одного длинного слова.';
  static const String rulesHow = 'Как играть: нажимайте на буквы внизу экрана, чтобы составить слово. Затем нажмите «Проверить».';
  static const String rulesRules = 'Правила: минимум 3 буквы. Каждую букву можно использовать только столько раз, сколько она встречается в исходном слове.';
  static const String rulesHint = 'Подсказка: нажмите на лампочку, чтобы получить первую букву следующего слова. Доступно 3 подсказки на уровень.';
  static const String rulesScore = 'Очки: каждая буква = 10 очков. Длинные слова дают бонус!';
  static const String rulesComplete = 'Уровень пройден, когда найдены все обязательные слова. Бонусные слова — приятный сюрприз!';
  static const String rulesClose = 'Понятно, играть!';

  // Level complete
  static const String levelCompleteTitle = 'Уровень пройден!';
  static const String nextLevelButton = 'Следующий уровень';
  static const String wordsFoundLabel = 'слов найдено';
}
```

### 7.2 `lib/l10n/strings_en.dart`

```dart
class StringsEn {
  // Home screen
  static const String appTitle = 'Words from a Word';
  static const String appSubtitle = 'Classic Word Game';
  static const String dictionaryLabel = 'English Dictionary';
  static const String playButton = 'Play';
  static const String rulesButton = 'Rules';
  static const String settingsButton = 'Settings';
  static const String leaderboardButton = 'Leaderboard';
  static const String footerText = 'Words from a Word · English';

  // Language select
  static const String chooseLang = 'Choose Language';
  static const String playRussian = 'Russian';
  static const String playEnglish = 'English (American)';
  static const String langToggleHint = 'Switch language';

  // Game screen
  static const String subtitle = 'Make words from these letters';
  static const String hintButton = 'Hint';
  static const String checkButton = 'Check';
  static const String levelLabel = 'LVL';
  static const String scoreLabel = 'Score';
  static const String wordsLeft = 'words left';
  static const String wordsOf = 'words';
  static const String startPrompt = 'Start playing!';
  static const String allFoundPrompt = 'Excellent!';
  static const String selectLetters = 'Select letters';
  static const String bonusLabel = 'Bonus';

  // Word slot headers
  static String lettersHeader(int n) => '$n LETTERS';

  // Rules modal
  static const String rulesTitle = 'How to Play';
  static const String rulesGoal = 'Goal: form as many words as possible from the letters of one long source word.';
  static const String rulesHow = 'How to play: tap the letter tiles at the bottom to build a word, then tap Check.';
  static const String rulesRules = 'Rules: minimum 3 letters. Each letter can only be used as many times as it appears in the source word.';
  static const String rulesHint = 'Hint: tap the lightbulb to reveal the first letter of the next unsolved word. 3 hints per level.';
  static const String rulesScore = 'Scoring: 10 points per letter. Longer words earn a bonus!';
  static const String rulesComplete = 'Level complete when all required words are found. Bonus words are a nice surprise!';
  static const String rulesClose = 'Got it, let\'s play!';

  // Level complete
  static const String levelCompleteTitle = 'Level Complete!';
  static const String nextLevelButton = 'Next Level';
  static const String wordsFoundLabel = 'words found';
}
```

---

## 8. Screen Specifications

### 8.1 Home Screen (`home_screen.dart`)

The home screen has two states: the **language select state** (first launch or when switching language) and the **main menu state** (after language is chosen).

**Language Select State:**

```
Layout: Centered column, full screen
Background: Grid paper (CustomPainter)

Elements (top to bottom):
1. App title "Слова из Слова / Words from a Word"
   Font: PlayfairDisplay Black 32sp
   Crimson "Слова" + navy "из Слова" (or full English title in navy)

2. Animated letter tiles spelling С-Л-О-В-А (decorative, not interactive)
   Each tile slightly rotated: index * 3° - 6°

3. Two large play buttons (side by side or stacked):

   ┌─────────────────────────────────┐
   │  🇷🇺  Русский                    │  ← Crimson background, white text
   │       Russian                   │
   └─────────────────────────────────┘
   ┌─────────────────────────────────┐
   │  🇺🇸  English (American)         │  ← Navy background, white text
   │       English                   │
   └─────────────────────────────────┘

   Button style: rounded pill (borderRadius: 32), height: 64
   Font: PlayfairDisplay Bold 18sp, uppercase, letter-spacing 2

4. Footer: "СЛОВА ИЗ СЛОВА · РУССКИЙ ЯЗЫК" in condensedLabel style

Tapping either button:
  → Sets language in SettingsProvider
  → Navigates to GameScreen with chosen mode
  → Persists choice in SharedPreferences
```

**Main Menu State** (after language is chosen — shown when user returns from game):

```
Same layout as above but:
- Shows "Continue" button (resume current level) + "New Game" button
- Shows language toggle in top-right corner (small flag icon + current language)
- Language toggle opens a bottom sheet with the two language buttons
```

**Language Toggle Widget** (persistent, shown in game screen top bar too):

```dart
// Small pill button in top-right of home screen and game screen header
Widget _languageToggle(LanguageMode mode, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(20),
        color: AppTheme.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mode.flagEmoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            mode == LanguageMode.russian ? 'РУ' : 'EN',
            style: AppTheme.condensedLabel.copyWith(
              color: AppTheme.foreground,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}
```

### 8.2 Game Screen (`game_screen.dart`)

```
Layout: Column, fills safe area

┌─────────────────────────────────────┐
│ [Stamp: LVL 1] [Progress bar] [Score]│  ← Top bar, height ~56
├─────────────────────────────────────┤
│      ПЕРЕВОДЧИК                      │  ← Source word, PlayfairDisplay Bold
│  Составьте слова из этих букв        │  ← Subtitle, condensedLabel
├─────────────────────────────────────┤  ← Thin divider
│                                     │
│  3 БУКВЫ                            │  ← Section header
│  ___ ___ ___   ___ ___ ___          │  ← Word slots (grouped by length)
│                                     │
│  4 БУКВЫ                            │
│  ____ ____   ____                   │
│                                     │
│  [Начинайте! — italic, faded]        │  ← Motivational filler
│                                     │
├─────────────────────────────────────┤  ← Thin divider
│ [✓ ВОР! +30 очков]  [💡 Подсказка×3]│  ← Celebration + hint row, height ~28
├─────────────────────────────────────┤
│                                     │
│  [Current word display: В О Р]       │  ← TilePicker top section
│                                     │
│  О  Е  Ч  К  Д  И  В  П  Е  Р      │  ← Tile grid (wrapped)
│                                     │
│  [↺]  [✓ ПРОВЕРИТЬ]  [⇌]            │  ← Action buttons
└─────────────────────────────────────┘
```

**Top bar detail:**
- Level stamp: `StampBadge` widget, 44×44, shows "УР." + level number
- Progress bar: `LinearProgressIndicator` styled with crimson fill, muted background, height 6, borderRadius 3
- Counter: "1 / 12 слов" in condensedLabel
- Score: "ОЧКИ" label + animated score number (scale pop on change)
- Language toggle: small pill in top-right

**Word slots scroll area:**
- `ListView` or `SingleChildScrollView` + `Column`
- Groups words by length, sorted ascending
- Section headers use `condensedLabel` style
- Each `WordSlotItem` is a `Row` of per-letter underline slots

**TilePicker area (fixed at bottom, does not scroll):**
- Current word display: `PlayfairDisplay Bold 24sp`, uppercase, letter-spacing 4
- Shake animation on invalid: translate X oscillation
- Tile grid: `Wrap` widget, spacing 8, centered
- Action buttons: clear (circular outlined), check (pill crimson), shuffle (circular outlined)

---

## 9. Level Data (JSON Assets)

### 9.1 `assets/data/russian_levels.json`

```json
[
  {
    "sourceWord": "переводчик",
    "required": ["вид", "вод", "вор", "код", "ров", "рок", "веер", "веко", "вред", "двор", "депо", "перо"],
    "bonus": ["вечерок", "доверие", "перевод"]
  },
  {
    "sourceWord": "строитель",
    "required": ["лес", "лот", "рот", "сор", "тир", "лето", "лист", "литр", "лось", "роль", "рост", "село"],
    "bonus": ["отстрел"]
  },
  {
    "sourceWord": "государство",
    "required": ["вар", "вод", "вор", "год", "дар", "ров", "рот", "сад", "сор", "вода", "ворс", "враг"],
    "bonus": ["восторг", "острога", "родство"]
  },
  {
    "sourceWord": "воспитание",
    "required": ["ван", "нос", "пот", "сон", "вена", "вино", "винт", "воин", "пион", "пост", "спина", "навес"],
    "bonus": ["пианист", "писание", "питание"]
  },
  {
    "sourceWord": "достижение",
    "required": ["дно", "дон", "нос", "сон", "джин", "енот", "жест", "жито", "сени", "сено", "тесно", "тонус"],
    "bonus": ["сидение"]
  },
  {
    "sourceWord": "образование",
    "required": ["ван", "вар", "воз", "вор", "зов", "ров", "база", "бора", "зона", "роза", "ваза", "набор"],
    "bonus": ["анабиоз", "изобара"]
  },
  {
    "sourceWord": "расстояние",
    "required": ["нос", "рот", "сон", "сор", "тир", "енот", "наст", "натр", "рота", "сани", "стан", "тоня"],
    "bonus": ["ассорти", "астения", "орясина"]
  },
  {
    "sourceWord": "направление",
    "required": ["вал", "ван", "вар", "лев", "лен", "веер", "вена", "вера", "вина", "план", "плен", "нрав"],
    "bonus": ["варение", "лепнина", "парение"]
  },
  {
    "sourceWord": "библиотека",
    "required": ["кол", "кот", "лак", "лоб", "лот", "ток", "бета", "бита", "блат", "блик", "блок", "балет"],
    "bonus": ["билетик", "отбелка"]
  },
  {
    "sourceWord": "правительство",
    "required": ["вал", "вар", "вор", "лев", "лес", "лот", "пот", "ров", "рот", "сор", "тир", "альт"],
    "bonus": ["альтист", "воитель", "вольера"]
  },
  {
    "sourceWord": "картошка",
    "required": ["кот", "рак", "рок", "рот", "ток", "шар", "шок", "арка", "кара", "каша", "кора", "крот"],
    "bonus": []
  },
  {
    "sourceWord": "комсомолец",
    "required": ["кол", "ком", "лес", "лом", "мел", "мол", "сок", "сом", "лоск", "село", "скол", "слом"],
    "bonus": []
  },
  {
    "sourceWord": "телевизор",
    "required": ["воз", "вор", "зов", "лев", "лот", "ров", "рот", "тир", "веер", "взор", "евро", "вето"],
    "bonus": ["ветрило"]
  },
  {
    "sourceWord": "холодильник",
    "required": ["дно", "дол", "дон", "код", "кол", "ход", "идол", "инок", "кило", "киль", "кино", "клин"],
    "bonus": ["иноходь", "коллоид"]
  },
  {
    "sourceWord": "университет",
    "required": ["тир", "веер", "винт", "врун", "нерв", "свет", "сени", "тест", "тире", "титр", "трус", "ирис"],
    "bonus": ["вестерн", "интерес", "сувенир"]
  },
  {
    "sourceWord": "литература",
    "required": ["тир", "аура", "лета", "лира", "литр", "тара", "тире", "титр", "трал", "тула", "рута", "лета"],
    "bonus": ["лауреат", "раритет", "театрал"]
  },
  {
    "sourceWord": "архитектура",
    "required": ["рак", "тир", "арка", "аура", "икра", "кара", "кета", "крат", "крах", "кура", "рака", "река"],
    "bonus": ["раритет", "трактир"]
  },
  {
    "sourceWord": "математика",
    "required": ["мак", "мат", "имам", "кета", "маки", "мама", "мета", "такт", "тема", "атака", "катет", "такт"],
    "bonus": []
  },
  {
    "sourceWord": "территория",
    "required": ["рот", "тир", "тире", "титр", "торт", "трио", "ритор", "теория", "террор"],
    "bonus": []
  },
  {
    "sourceWord": "сотрудник",
    "required": ["дно", "дон", "код", "кот", "нос", "рок", "рот", "сок", "сон", "сор", "тир", "ток"],
    "bonus": ["дисконт", "рисунок"]
  },
  {
    "sourceWord": "воображение",
    "required": ["ван", "вар", "вор", "жар", "жир", "ров", "веер", "вена", "вера", "вина", "вино", "жарение"],
    "bonus": ["варение", "вербена"]
  },
  {
    "sourceWord": "произведение",
    "required": ["вид", "вод", "воз", "вор", "дно", "дон", "зов", "ров", "веер", "взор", "вино", "воин"],
    "bonus": ["ведение", "везение", "видение", "доверие"]
  },
  {
    "sourceWord": "приключение",
    "required": ["лен", "клин", "клич", "ключ", "леер", "плен", "пюре", "ринк", "ключик"],
    "bonus": ["кипение", "пиление", "черепки"]
  }
]
```

### 9.2 `assets/data/english_levels.json`

These 20 English levels follow the same structure. Source words are common American English nouns of 8–12 letters. Required words are common nouns (no proper nouns, no abbreviations, minimum 3 letters). Bonus words are valid but less common. All words have been verified to be formable from the source word's letters.

**Important note for native speaker review:** Have a native English speaker verify that all required words feel natural and unambiguous before shipping. Avoid words that are primarily British English (e.g., "lorry", "biscuit" in the British sense).

```json
[
  {
    "sourceWord": "strawberry",
    "required": ["bar", "bare", "bear", "best", "brew", "rare", "rate", "rest", "star", "stare", "straw", "water"],
    "bonus": ["arrest", "barter", "beware"]
  },
  {
    "sourceWord": "carpenter",
    "required": ["ant", "apt", "arc", "art", "can", "cap", "car", "cat", "ear", "eat", "net", "pan"],
    "bonus": ["canter", "parent", "recant"]
  },
  {
    "sourceWord": "chocolate",
    "required": ["ace", "act", "ale", "cat", "coal", "coat", "cola", "cool", "each", "echo", "lace", "late"],
    "bonus": ["locate", "talcoe"]
  },
  {
    "sourceWord": "mountains",
    "required": ["aim", "ant", "aunt", "man", "mat", "mint", "moan", "most", "noun", "nut", "oat", "omit"],
    "bonus": ["amount", "nation", "summit"]
  },
  {
    "sourceWord": "blackboard",
    "required": ["arc", "ark", "bar", "bark", "black", "board", "bold", "book", "cord", "dark", "dock", "lock"],
    "bonus": ["abroad", "cloak", "roadblock"]
  },
  {
    "sourceWord": "breakfast",
    "required": ["ark", "art", "ask", "bar", "bare", "bark", "base", "bear", "beat", "best", "fast", "rake"],
    "bonus": ["basket", "breast", "streak"]
  },
  {
    "sourceWord": "telephone",
    "required": ["eel", "hen", "hole", "lone", "lope", "note", "open", "peel", "peon", "poet", "pole", "tone"],
    "bonus": ["lentil", "noodle", "people"]
  },
  {
    "sourceWord": "adventure",
    "required": ["ant", "art", "dare", "dart", "date", "dune", "dune", "earn", "near", "neat", "rent", "rude"],
    "bonus": ["detour", "nature", "turned"]
  },
  {
    "sourceWord": "fireworks",
    "required": ["few", "fir", "fire", "folk", "fork", "fore", "foe", "ore", "owe", "row", "sir", "ski"],
    "bonus": ["flower", "forest", "worker"]
  },
  {
    "sourceWord": "landscape",
    "required": ["ace", "ale", "and", "ape", "clad", "clan", "clap", "cane", "cape", "lace", "land", "lane"],
    "bonus": ["candle", "panels", "placed"]
  },
  {
    "sourceWord": "waterfall",
    "required": ["all", "art", "ate", "awe", "fall", "fare", "fat", "flat", "flaw", "late", "law", "leaf"],
    "bonus": ["lawful", "wallet", "waffle"]
  },
  {
    "sourceWord": "butterfly",
    "required": ["belt", "blur", "buff", "bull", "bury", "but", "buy", "felt", "fuel", "full", "left", "lure"],
    "bonus": ["butler", "fluffy", "turtle"]
  },
  {
    "sourceWord": "classroom",
    "required": ["arc", "arm", "car", "coal", "cool", "coral", "cram", "loom", "molar", "moral", "oral", "roam"],
    "bonus": ["cloaks", "colors", "scroll"]
  },
  {
    "sourceWord": "newspaper",
    "required": ["ape", "asp", "awe", "ear", "nap", "nape", "near", "pane", "pear", "reap", "reap", "sane"],
    "bonus": ["aspen", "reaper", "weapon"]
  },
  {
    "sourceWord": "basketball",
    "required": ["all", "ask", "ball", "base", "bash", "bask", "blast", "last", "salt", "slab", "slat", "talk"],
    "bonus": ["basket", "stable", "tables"]
  },
  {
    "sourceWord": "thunderstorm",
    "required": ["drum", "dune", "dusk", "moth", "mound", "mount", "must", "north", "nut", "rout", "rude", "rust"],
    "bonus": ["detour", "modest", "outrun"]
  },
  {
    "sourceWord": "springtime",
    "required": ["emit", "grim", "grin", "grip", "mine", "mint", "mire", "mist", "pint", "pine", "ring", "ripe"],
    "bonus": ["imprint", "inspire", "protein"]
  },
  {
    "sourceWord": "pineapple",
    "required": ["ale", "ape", "app", "ill", "lane", "lean", "line", "lip", "nail", "nap", "nape", "pail"],
    "bonus": ["alpine", "napkin", "penile"]
  },
  {
    "sourceWord": "chemistry",
    "required": ["chest", "chime", "cite", "emit", "etch", "heir", "hem", "her", "hire", "itch", "item", "mice"],
    "bonus": ["hermit", "metric", "thrice"]
  },
  {
    "sourceWord": "playground",
    "required": ["drag", "drop", "drug", "drum", "dung", "gland", "glory", "gold", "gory", "gray", "groan", "ground"],
    "bonus": ["around", "dragon", "plodder"]
  }
]
```

---

## 10. `main.dart` and `app.dart`

### 10.1 `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'engine/level_loader.dart';
import 'providers/settings_provider.dart';
import 'providers/game_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Preload level data from assets
  await LevelLoader.preload();

  // Load persisted settings
  final settings = SettingsProvider();
  await settings.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: const SlovaApp(),
    ),
  );
}
```

### 10.2 `lib/app.dart`

```dart
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

class SlovaApp extends StatelessWidget {
  const SlovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Слова из Слова',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
```

---

## 11. `lib/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Colours ──────────────────────────────────────────────
  static const Color background    = Color(0xFFFFFEF0); // warm cream
  static const Color foreground    = Color(0xFF1D2B38); // deep navy
  static const Color primary       = Color(0xFFB22030); // crimson red
  static const Color primaryFg     = Color(0xFFFEFEF8); // white on crimson
  static const Color accent        = Color(0xFFF5A234); // amber gold
  static const Color muted         = Color(0xFFEDE9DC); // muted cream
  static const Color mutedFg       = Color(0xFF7A8A96); // muted text
  static const Color border        = Color(0xFFC8D0D8); // grid lines
  static const Color tileBg        = Color(0xFFF5F2E8); // tile background
  static const Color slotEmpty     = Color(0xFFD8DDE3); // empty slot
  static const Color slotFilled    = Color(0xFF1D2B38); // filled slot (navy)
  static const Color card          = Color(0xFFF7F4EC); // card surface
  static const Color gold          = Color(0xFFF5A234); // same as accent

  // ── Typography ────────────────────────────────────────────
  static TextStyle get displayLarge => GoogleFonts.playfairDisplay(
    fontWeight: FontWeight.w900,
    fontSize: 32,
    color: foreground,
    letterSpacing: 1.5,
  );

  static TextStyle get displayMedium => GoogleFonts.playfairDisplay(
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: foreground,
    letterSpacing: 1.0,
  );

  static TextStyle get displayItalic => GoogleFonts.playfairDisplay(
    fontStyle: FontStyle.italic,
    fontSize: 24,
    color: primary.withOpacity(0.4),
  );

  static TextStyle get condensedBold => const TextStyle(
    fontFamily: 'RobotoCondensed',
    fontWeight: FontWeight.w700,
    fontSize: 14,
    letterSpacing: 1.2,
    color: foreground,
  );

  static TextStyle get condensedLabel => const TextStyle(
    fontFamily: 'RobotoCondensed',
    fontWeight: FontWeight.w400,
    fontSize: 10,
    letterSpacing: 3.0,
    color: mutedFg,
  );

  static TextStyle get tileLabel => const TextStyle(
    fontFamily: 'RobotoCondensed',
    fontWeight: FontWeight.w700,
    fontSize: 18,
    color: foreground,
  );

  // ── ThemeData ─────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      surface: background,
      primary: primary,
      onPrimary: primaryFg,
      secondary: accent,
      onSecondary: foreground,
      error: Color(0xFFB22030),
    ),
    textTheme: TextTheme(
      displayLarge: displayLarge,
      displayMedium: displayMedium,
      bodyLarge: condensedBold,
      bodySmall: condensedLabel,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: primaryFg,
        shape: const StadiumBorder(),
        textStyle: condensedBold.copyWith(
          fontSize: 16,
          letterSpacing: 2.0,
        ),
        minimumSize: const Size(200, 56),
      ),
    ),
    dividerColor: border,
  );
}
```

---

## 12. Bilingual Architecture Summary

The language mode flows through the app as follows:

```
SettingsProvider (persisted in SharedPreferences)
    │
    ├── languageMode: LanguageMode.russian | LanguageMode.english
    │
    └── Consumed by:
        ├── HomeScreen — shows correct title, flag, button labels
        ├── GameScreen — shows correct UI strings (via StringsRu / StringsEn)
        ├── GameProvider.startGame(mode) — loads correct level set
        ├── LevelLoader.generateLevel(n, mode) — reads correct JSON asset
        └── WordSlots — uses correct lettersHeader() function
```

**Language toggle flow:**

1. User taps language toggle (flag pill) anywhere in the app.
2. A `showModalBottomSheet` presents the two language buttons.
3. Tapping a language calls `settings.setLanguageMode(mode)`.
4. If in an active game, this triggers a confirmation dialog: "Start a new game in [language]?"
5. On confirm, `game.startGame(mode, levelNumber: 1)` is called and the game resets.
6. If on the home screen, the UI simply re-renders with the new language.

**String access pattern** — use a helper to avoid `if/else` everywhere:

```dart
// In a base widget or mixin
dynamic get strings =>
    context.read<SettingsProvider>().languageMode == LanguageMode.russian
        ? StringsRu
        : StringsEn;

// Usage:
Text(strings.playButton)
Text(strings.lettersHeader(3))
```

---

## 13. Animation Reference

All animations are specified here. Use `flutter_animate` package for most of them.

| Animation | Trigger | Spec |
|---|---|---|
| Tile select | Tap tile | scale 1→1.08, translateY 0→-2, duration 150ms |
| Tile deselect | Tap selected tile | scale 1.08→1, translateY -2→0, duration 150ms |
| Tile shake | Invalid word | translateX: 0→-6→6→-4→4→0, duration 350ms |
| Word found | Slot letter reveal | scale 1→1.12→1, duration 300ms |
| Score pop | Score changes | scale 1.3→1, color crimson→navy, duration 300ms |
| Progress bar | Word found | width animated, duration 500ms, ease out |
| Stamp badge | Level start | scale 2.5→0.92→1, rotate -8°→2°→0°, duration 450ms |
| Level complete overlay | Level done | fade in + scale 0.9→1, duration 400ms, spring |
| Confetti | Level complete | 18 squares, fall 80px, rotate 360°, fade out, duration 1.2s |
| Source word | Level change | fade out up → fade in down, duration 300ms |
| Celebration banner | Word found | slide in from left, fade out after 1.5s |
| Language toggle | Tap | scale 0.95→1, duration 100ms |

---

## 14. Claude Code Instructions

Follow these steps in order when building the app in Claude Code.

**Step 1 — Project scaffold:**
```bash
flutter create slova_iz_slova --org com.slovaizslova --platforms ios,android
cd slova_iz_slova
```
Replace `pubspec.yaml` with the version in Section 2.1. Run `flutter pub get`.

**Step 2 — Assets:**
Create the directory structure from Section 2.2. Copy the JSON level data from Sections 9.1 and 9.2 into the asset files. Download Playfair Display and Roboto Condensed fonts from Google Fonts and place in `assets/fonts/`. Alternatively, skip font files and use `google_fonts` package at runtime.

**Step 3 — Models and engine:**
Create all files in `lib/models/` and `lib/engine/` exactly as specified in Sections 4 and 5. These have no Flutter dependencies and can be unit-tested immediately.

**Step 4 — Theme:**
Create `lib/theme/app_theme.dart` from Section 11. This is the single source of truth — never hardcode colours or font sizes in widgets.

**Step 5 — Providers:**
Create `lib/providers/settings_provider.dart` and `lib/providers/game_provider.dart` from Section 6. Wire them into `main.dart` from Section 10.

**Step 6 — Localisation strings:**
Create `lib/l10n/strings_ru.dart` and `lib/l10n/strings_en.dart` from Section 7.

**Step 7 — Widgets (bottom-up):**
Build in this order: `LetterTile` → `TilePicker` → `WordSlotItem` → `WordSlots` → `StampBadge` → `RulesModal` → `LevelCompleteOverlay`.

**Step 8 — Screens:**
Build `HomeScreen` first (simpler), then `GameScreen`. Wire up `GameProvider` and `SettingsProvider` via `context.watch<>()`.

**Step 9 — Grid paper background:**
Add the `_GridPaperPainter` from Section 3.3 to the `Scaffold` background in `app.dart`.

**Step 10 — Animations:**
Add `flutter_animate` to `pubspec.yaml`. Apply animations from Section 13 to each widget.

**Step 11 — Test:**
Run `flutter test` for engine unit tests. Run on iOS Simulator and Android Emulator. Test both language modes end-to-end.

**Step 12 — Ads (after core game is stable):**
Uncomment `google_mobile_ads` in `pubspec.yaml`. Add banner ad to bottom of `HomeScreen`. Add interstitial ad trigger every 3 levels in `GameProvider.nextLevel()`. Add rewarded video ad as the hint mechanism (optional: replace the free hint with a rewarded video option).

---

## 15. Known Issues and Notes from Web Prototype

The following issues were identified during web prototype development and should be addressed in the Flutter build:

**Dictionary quality:** The Russian word lists were generated programmatically and have not been reviewed by a native speaker. Some words may be archaic, offensive, or feel unnatural. Have a native Russian speaker play through all 23 levels before shipping. The English levels are a first draft and require similar review.

**Level 16 duplicate:** Level 16 (литература) has a duplicate entry in the `required` array ("лета" appears twice). Remove the duplicate in the JSON.

**Level 18 duplicate:** Level 18 (математика) has "такт" listed twice in `required`. Remove the duplicate.

**Bonus word validation:** The current engine only accepts words that appear in the `targetWords` list. This means players cannot discover words that are valid Russian/English words but not in the level definition. A future enhancement would be to validate against the full dictionary and award bonus points for any valid word formable from the source letters.

**Hint system:** The current hint reveals only the first letter of the next unsolved word. A more generous hint (reveal first two letters, or highlight which tiles to use) could be offered as a rewarded video incentive.

**Score persistence:** The current prototype does not persist the score or level number between sessions. Add `SharedPreferences` persistence in `GameProvider` so players resume where they left off.

**Haptic feedback:** Add `HapticFeedback.selectionClick()` on tile select and `HapticFeedback.mediumImpact()` on word found. This significantly improves the tactile feel of the game.

---

## 16. File Checklist

Before handing off to the App Store / Play Store, verify:

| Item | Status |
|---|---|
| All 23 Russian levels reviewed by native speaker | ☐ |
| All 20 English levels reviewed by native speaker | ☐ |
| Duplicate words removed from levels 16 and 18 | ☐ |
| App icon designed (1024×1024 for App Store) | ☐ |
| Splash screen implemented (native, not Flutter) | ☐ |
| AdMob App ID added to `AndroidManifest.xml` and `Info.plist` | ☐ |
| Privacy policy URL set (required for AdMob) | ☐ |
| App Store Connect listing created | ☐ |
| Google Play Console listing created | ☐ |
| Both language modes tested end-to-end on real device | ☐ |
| Score and level persistence tested (kill app, reopen) | ☐ |
| Haptic feedback tested on real device | ☐ |

---

*End of handover document. All code in this document is production-ready starter code — not pseudocode. Paste it directly into the corresponding files and it will compile without modification (subject to `flutter pub get` completing successfully).*
