# Слова из Слова — CLAUDE.md

Project guide for Claude Code. Read this first, then `docs/DECISIONS.md` for the decision log, and `docs/FLUTTER_HANDOVER.md` for the original spec.

---

## What this project is

A bilingual (Russian/English) casual word game for the Russian-speaking US diaspora. Players are given a long source word and must form shorter words by tapping letter tiles. The design aesthetic is **Soviet Notebook** — cream paper background, navy ink typography, crimson red accents, amber gold rewards.

- **Platform:** iOS + Android (Flutter only, no web)
- **State management:** Provider (ChangeNotifier)
- **Animations:** flutter_animate
- **Fonts:** google_fonts package (runtime loading — no bundled `.ttf` files)
- **Haptics:** Flutter's built-in `HapticFeedback` from `package:flutter/services.dart`
- **Persistence:** shared_preferences (language mode only)
- **No backend** — all game data bundled as JSON assets
- **Ads:** commented out in `pubspec.yaml`, to be added later

---

## Current status

**v1.0 complete.** Full game is built, tested, and on `main`. `flutter analyze` reports zero issues. All 10 unit tests pass.

### What's built
- 23 Russian levels + 20 English levels (all words audited and validated against source letters)
- Full game loop: tile selection → word submission → scoring → level complete
- Hint system (3 hints per level; auto-selects first letter of the next unfound word)
- Level complete overlay with confetti animation
- Home screen with Russian/English language selection
- In-game language toggle (bottom sheet)
- Grid paper background (CustomPainter)
- Bilingual UI strings (`StringsRu`, `StringsEn`)
- Score persists across levels; hints reset per level

### What's not built yet
- Ad placements (`google_mobile_ads` dependency is commented out)
- Dictionary-backed open word entry (bonus detection currently level-defined only)
- App icon and splash screen (Flutter defaults)
- Score persistence across sessions
- Daily challenges / push notifications

---

## Build commands

```bash
flutter run                        # Run on connected device/emulator
flutter test                       # Run unit tests
flutter analyze                    # Static analysis (must be zero issues before commit)
flutter build apk --release        # Android release build
flutter build ios --release        # iOS release build
```

---

## Architecture

```
lib/
├── main.dart                       # Entry point: portrait lock, preload, providers
├── app.dart                        # MaterialApp + AppTheme + HomeScreen
├── engine/
│   ├── game_engine.dart            # Pure static logic: letterCount, canFormWord,
│   │                               #   validateWord, scoreWord, isLevelComplete
│   └── level_loader.dart           # Loads + caches JSON; generates GameLevel objects
├── models/
│   ├── game_state.dart             # LetterTile, TargetWord, GameLevel, GameState
│   │                               #   (all immutable, all have copyWith)
│   └── language_mode.dart          # LanguageMode enum with displayName/flag/asset extensions
├── providers/
│   ├── game_provider.dart          # Tile selection, submit, shake, hint, nextLevel
│   └── settings_provider.dart      # Language mode persisted to SharedPreferences
├── screens/
│   ├── home_screen.dart            # Language select, rules button, decorative tiles
│   └── game_screen.dart            # Top bar, source word, word slots, tile picker
├── theme/
│   └── app_theme.dart              # All colours, typography, ThemeData — single source of truth
├── widgets/
│   ├── letter_tile.dart            # Animated tappable tile (48×48, scale + shadow on select)
│   ├── tile_picker.dart            # Tile grid + current word input + action buttons
│   ├── word_slots.dart             # Groups target words by length; bonus section separate
│   ├── word_slot_item.dart         # Single word slot row with letter-reveal animation
│   ├── stamp_badge.dart            # Circular crimson level number stamp
│   ├── level_complete_overlay.dart # Full-screen win screen with confetti
│   ├── rules_modal.dart            # Bottom sheet rules
│   └── grid_paper_background.dart  # CustomPainter: 20px grid on cream background
└── l10n/
    ├── strings_ru.dart             # All Russian UI strings
    └── strings_en.dart             # All English UI strings
```

---

## Key data structures

**`GameState`** (immutable, updated via `copyWith`):

| Field | Type | Notes |
|---|---|---|
| `level` | `GameLevel` | Source word + letter tiles + target words |
| `selectedTileIds` | `List<String>` | Ordered; drives `currentInput` |
| `foundWords` | `List<String>` | All words found this session |
| `score` | `int` | Cumulative; persists across levels |
| `hintsRemaining` | `int` | Starts at 3; resets each level |
| `isShaking` | `bool` | Triggers 400ms shake on invalid submit |
| `lastFoundWord` | `String?` | Displayed for 1500ms after each find |
| `isLevelComplete` | `bool` | True when all non-bonus words are found |

**`TargetWord`**: `word`, `length`, `isFound`, `isBonus`

**Scoring formula:** `(word.length × 10) + bonus`
Bonus: 0 pts for ≤3 letters, 10 for 4, 20 for 5, 30 for 6+

---

## Level data format

`assets/data/russian_levels.json` and `assets/data/english_levels.json`:

```json
[
  {
    "sourceWord": "переводчик",
    "required": ["век", "вор", "вечер"],
    "bonus": ["перо", "кедр"],
    "tooCommon": ["три", "вот"],
    "blocked": []
  }
]
```

`LevelLoader` validates all words against `sourceWord` using `GameEngine.canFormWord()` at load time.

---

## Design system

All colours and typography are in `lib/theme/app_theme.dart`. Never hardcode values.

| Token | Value | Usage |
|---|---|---|
| `AppTheme.background` | `#FFFEF0` | App background (cream) |
| `AppTheme.foreground` | `#1D2B38` | Primary text (navy) |
| `AppTheme.primary` | `#B22030` | Crimson — CTAs, stamps, progress bar |
| `AppTheme.accent` | `#F5A234` | Amber gold — bonus words, rewards |
| `AppTheme.muted` | `#EDE9DC` | Disabled states |
| `AppTheme.tileBg` | `#F5F2E8` | Letter tile background |
| `AppTheme.tileLabel` | RobotoCondensed 18px bold | Tile letters |
| `AppTheme.displayMedium` | PlayfairDisplay 24px bold | Source word |
| `AppTheme.condensedLabel` | RobotoCondensed 10px, 3px tracking | Small labels |

---

## Conventions

- Models are immutable. All mutations use `copyWith()`.
- Engine methods are pure static functions with no side effects.
- Providers hold all mutable state and call `notifyListeners()` after each change.
- Use `context.watch<T>()` in `build()` methods; `context.read<T>()` in callbacks.
- No inline colours or font sizes anywhere outside `app_theme.dart`.
- All user-visible strings go through `StringsRu` or `StringsEn`.
- The `// ignore: deprecated_member_use` comments in `letter_tile.dart` are intentional — they suppress Matrix4 `scale`/`translate` deprecation warnings where no clean replacement exists.

---

## Repository

GitHub: https://github.com/robchambo/words-from-a-word
