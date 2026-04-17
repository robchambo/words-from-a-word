# Decision Log

Key decisions made during the initial build. Read alongside `CLAUDE.md` and `docs/FLUTTER_HANDOVER.md`.

---

## D1 — No dictionary files; validation is level-only

**Decision:** Word validation is purely against each level's `targetWords` list. The `russian_valid_words.txt` and `english_valid_words.txt` files from the original spec were not created.

**Why:** Dictionary files add asset weight, require loading and Set construction at startup, and enable arbitrary word entry — which is a different (harder) game design. The curated level approach gives the game designer full control over which words count. Open-ended bonus detection can be added later if needed.

**Impact:** `assets/data/*.txt` files do not exist and are not referenced in `pubspec.yaml`. `engine/dictionary.dart` from the spec was never created.

---

## D2 — Runtime Google Fonts, not bundled font files

**Decision:** Use the `google_fonts` package to load PlayfairDisplay and RobotoCondensed at runtime. No `.ttf` files are bundled in `assets/fonts/`.

**Why:** Simpler development setup; no font download step before first build.

**Future action:** For production, pre-bundle the fonts to remove the network dependency on first run. See the `google_fonts` package docs for how to use cached fonts.

**Impact:** `pubspec.yaml` has no `fonts:` section. Fonts are fetched from Google CDN on first launch (cached thereafter).

---

## D3 — Built-in HapticFeedback, not flutter_vibrate

**Decision:** Use Flutter's built-in `HapticFeedback` (from `package:flutter/services.dart`). `flutter_vibrate` is not a dependency.

**Why:** `flutter_vibrate` requires additional native setup (Android permissions, iOS entitlements). Built-in `HapticFeedback` covers `.selectionClick()`, `.mediumImpact()`, and `.heavyImpact()` — sufficient for tile taps and word submissions.

**Impact:** `flutter_vibrate` is not in `pubspec.yaml`. `game_provider.dart` uses `HapticFeedback` directly.

---

## D4 — Ads scaffolding only (not implemented)

**Decision:** `google_mobile_ads` is listed in `pubspec.yaml` as a commented-out dependency. No ad placements or ad initialisation code has been written.

**Why:** Core gameplay shipped first. Ads will be added in a dedicated sprint.

**How to implement:** Uncomment the dependency, run `flutter pub get`, then add ad placements. Intended location: interstitial between levels. Banner at bottom of game screen is also an option.

---

## D5 — Required words capped at 12 per level

**Decision:** `LevelLoader.generateLevel()` silently caps required words at 12, even if the JSON defines more. Words beyond 12 are dropped (not demoted to bonus).

**Why:** Keeps each level session to a manageable length. Any level JSON that defines more than 12 required words will be trimmed at load time.

---

## D6 — Score persists across levels; hints reset per level

**Decision:** `GameProvider.nextLevel()` carries `score` forward but resets `hintsRemaining` to 3.

**Why:** A cumulative score is motivating and gives players a session total to be proud of. Hints resetting per level keeps them meaningful — if they carried over, players would hoard them or run out early.

---

## D7 — All English levels audited and corrected

**Decision:** All 20 English levels were audited with a Node.js validation script before the initial push. Any word that couldn't be formed from its source word's letters was replaced with a valid alternative.

**Why:** The original Manus spec had formation errors in several levels (words requiring letters not present in the source word). These would have caused words to silently fail validation at runtime.

**Impact:** `assets/data/english_levels.json` differs from the original spec in several levels. It is the authoritative version. Do not replace it with the original spec's data.

---

## D8 — Soviet Notebook design followed as-is

**Decision:** No UI decisions deviated from the spec. The Manus handover document and React prototype were aligned, so no design comparisons were needed.

**Why:** The spec was clear and internally consistent.

---

## D9 — flutter_svg and flutter_localizations not used

**Decision:** `flutter_svg` and `flutter_localizations` (listed in the original spec's `pubspec.yaml`) were not added as dependencies.

**Why:** No SVG assets are used — the design is achieved with Flutter primitives and CustomPainter. Localisation is handled by simple `StringsRu`/`StringsEn` constant classes, which is sufficient for a two-language app without needing the full ARB/intl pipeline.

---

## D10 — Level IDs derived from array position; explicit end-of-library screen

**Decision (recorded 2026-04-16, during Phase 0 of the v1.1 roadmap):** Two related choices about level data:

1. **Level JSON does not carry an explicit `id` field.** `LevelLoader.generateLevel(levelNumber)` derives the ID from its `levelNumber` parameter (which is the 1-indexed array position + 1). An earlier GDD example showed `"id": 1` in the JSON — that example was wrong and has been corrected in §5.1.
2. **End-of-library silent wrap is a v1.0 bug, not a feature.** `LevelLoader.generateLevel` currently does `(levelNumber - 1) % defs.length`, so finishing the last level and tapping "Next level" silently restarts at level 1. This was never intentional. v1.1 replaces it with an explicit "library complete" screen that offers free-mode replays of completed levels (score/best/lifetime not affected). See GDD §5.7.

**Why (1):** Adding `id` to JSON creates a source-of-truth conflict — if the JSON `id` ever drifted from array position (e.g. during a reorder for difficulty tuning), behaviour would depend on whether code uses the array index or the field. Keeping derivation canonical removes that hazard.

**Why (2):** Silent wrap destroys the sense of progression once a user reaches the end, and hides lifetime/best-score stats that should be celebrated. An explicit screen is more rewarding, supports the free-mode replay pattern (which lets hint-farmers grind without inflating stats), and is the obvious place to advertise upcoming content.

**Impact:** Level JSONs remain as-is (no rewrite needed). `LevelLoader.generateLevel` must change in v1.1 to throw/return-null when `levelNumber > defs.length`, and `GameProvider.nextLevel` must handle that result by routing to the library-complete screen. The code change is scheduled for Phase 3 of the v1.1 roadmap.
