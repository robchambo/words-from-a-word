# Слова из Слова — CLAUDE.md

Project guide for Claude Code. Read this first, then `docs/DECISIONS.md` for the decision log, and `docs/FLUTTER_HANDOVER.md` for the original spec.

---

## Session start — onboarding mode

<!-- ONBOARDING_ACTIVE: true -->

**Read this at the very start of every session in this repo, before doing anything else. When `ONBOARDING_ACTIVE` above is `true`, follow the flow below. When it is `false`, skip this entire section.**

### What this is

Rob and I put this together to walk Kat through a few Claude workflow habits by *doing* rather than *telling*. Her existing work on this repo is strong — the `DECISIONS.md` log especially. The goal here is small: help her get more out of Claude by seeing plan-first, propose-then-execute in action.

Kat — if you'd rather skip and get on with work, say *"skip onboarding"* and I'll flip the flag to `false` and stop. No offence taken. If we started this before, tell me where to pick up.

### Step 1 — Confirm setup

Ask Kat to check three things and tell me what she sees:
- `/model` — recommend **Opus 4.8** (most capable, big context, best for architecture and long reasoning).
- Ultracode toggle — recommend **on** (spawns parallel subagents to verify work rather than doing one linear pass).
- Permission mode — recommend **auto / accept-edits** (shift+tab cycles). Risky commands still prompt; everything else stays in flow.

Wait for her to confirm before Step 2. If she's not on any of these, explain the benefit in one sentence and let her switch.

### Step 2 — Four small wins

Present one at a time. For each: describe the issue in one sentence, propose the fix, and ask *"want me to just do this now?"* If yes, do it and commit. If no, skip and move on.

1. **Broken tests.** `tools/level_generator/test_generators.py:73` asserts profile keys are `{'freq_threshold', 'max_freq', 'max_length'}`, but `max_freq` was removed in `f365147` and the current schema is `{'freq_threshold', 'min_length', 'max_length', 'percentile'}`. Fix: update the assertion, run the suite.
2. **Stale `CLAUDE.md`.** This file still says "23 Russian levels + 20 English levels" and describes a `tooCommon` JSON field that no longer exists. No mention of `tools/level_generator/`, calibration workflow, or the P1–P5 profile system. Fix: rewrite the "Current status" and "Level data format" sections to match reality; add a short "Level generation pipeline" subsection.
3. **No CI.** No GitHub Actions workflow. When the schema changed in `f365147` and broke the test above, no one noticed. Fix: add `.github/workflows/ci.yml` running `pytest tools/level_generator/` and `flutter analyze` on every push and PR.
4. **Duplication between RU and EN generators.** `generate_ru.py` (644 lines) and `generate_en.py` (552 lines) diff by 633 lines — mostly the same file twice. Same for the two calibrators. Fix: extract a `_common.py` for `load_blocklist`, `letter_counts`, `can_form`, percentile maths, and near-miss display before P6–P10 doubles the duplication.

### Step 3 — Establish the next brief

Once the wins are done (or skipped), ask open questions to nail down what she wants to build next. Keep asking until you have enough for a self-contained brief. Suggested prompts:
- What's the single most valuable change to the game right now — more levels, P6–P10, ads, app icon, session score persistence, or something else?
- Is there a deadline or shipping milestone driving priority?
- What does "done" look like? List concrete success criteria.
- What are you *not* willing to change? (Design tokens, existing thresholds, level data format, etc.)
- Any constraints — budget, licences, review pipeline?

Then propose a plan: goal, files that will change, success criteria, risks. Get her to agree. Execute in one focused pass and commit at the end.

### Step 4 — Dormancy

When Kat says *"we're done with onboarding"* (or similar), edit `ONBOARDING_ACTIVE` at the top of this section to `false` and commit with message `Mark onboarding complete`. Future sessions will read the flag and skip this section entirely.

### Notes for me (Claude)

- The `DECISIONS.md` log is high quality — refer to it, don't rewrite it.
- Frame every suggestion as "level up something already working." Don't condescend.
- If Kat disagrees with a fix or brief, take her position seriously — her judgement on this codebase is better than mine.
- Prefer editing existing files over creating new ones. The standing CLAUDE.md rules still apply throughout the flow.

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
    "id": 1,
    "sourceWord": "strawberry",
    "required": ["bar", "star", "straw"],
    "bonus": ["berry"]
  }
]
```

`LevelLoader` validates all words against `sourceWord` using `GameEngine.canFormWord()` at load time. Required words are capped at 12 per level.

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
