# Decision Log

Key decisions made during the initial build. Read alongside `CLAUDE.md` and `docs/FLUTTER_HANDOVER.md`.

---

## D1 — No dictionary files; validation is level-only *(superseded by D10)*

**Decision:** Word validation is purely against each level's `targetWords` list. The `russian_valid_words.txt` and `english_valid_words.txt` files from the original spec were not created.

**Why:** Dictionary files add asset weight, require loading and Set construction at startup, and enable arbitrary word entry — which is a different (harder) game design. The curated level approach gives the game designer full control over which words count. Open-ended bonus detection can be added later if needed.

**Impact:** `assets/data/*.txt` files do not exist and are not referenced in `pubspec.yaml`. `engine/dictionary.dart` from the spec was never created.

*This decision was revisited and reversed. See D10.*

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

## D10 — Dynamic dictionary with frequency-based word classification (supersedes D1)

**Decision:** Word validation is backed by a real frequency-ranked word list (`assets/data/ru_freq.txt`), sourced from [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) (MIT licence). Words formable from the source letters are classified at level-load time rather than hand-curated per level.

**Classification rules:**
- **Required** — in dictionary, ≤6 letters, frequency rank above threshold → shown as blank slots in the existing UI
- **Bonus** — in dictionary, >6 letters OR frequency rank below threshold → dynamically discovered, shown in bonus section
- **Excluded** — suppressed via per-level `overrides` in the level JSON (e.g. words that appear across too many levels) → accepted but award no points

**Why:** Hand-curated word lists miss valid words (e.g. "род" in level 1), require ongoing maintenance, and don't scale to 50+ levels. A frequency-ranked dictionary gives players a consistent and fair experience while keeping common words as required targets and rare/long words as rewarding discoveries.

**Thresholds:** Frequency cut-off and length cut-off (currently 6 letters) are named constants in `engine/dictionary.dart`. Both can be changed in one place without touching level data or game logic.

**Word classification enum:** `WordClass { required, bonus, excluded }`. Adding a new category is a one-line change to the enum.

**Per-level overrides:** Level JSON may include an `overrides` block to demote specific words regardless of their dictionary classification:
```json
{ "sourceWord": "переводчик", "overrides": { "excluded": ["вор"] } }
```

**Source word selection:** Source words (12+ letters) are chosen manually to ensure levels are interesting and consistent across users. A pool of 50 initial source words will be selected together, spanning high, medium, and low frequency.

**Impact:** `engine/dictionary.dart` created. `engine/level_loader.dart` rewritten. `assets/data/ru_freq.txt` bundled. Level JSON simplified to `sourceWord` + optional `overrides`. Old hand-curated `required`/`bonus` arrays removed.
