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

## D10 — Frequency-ranked dictionary as the source of truth for word lists (supersedes D1; refined by D11)

**Decision:** Word lists are derived from a frequency-ranked dictionary (`assets/data/ru_freq.txt`), sourced from [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) (MIT licence), rather than hand-curated per level.

**Classification rules:**
- **Too common** — frequency at or above upper threshold → formable but returns "Слово слишком распространено!" and zero points; stored in `tooCommon` array in the level JSON
- **Required** — frequency in the medium band (between lower and upper thresholds), length ≤ max length → shown as blank slots
- **Bonus** — frequency below lower threshold OR length above max length → discovered dynamically, shown in bonus section
- **Excluded** — suppressed via per-level `overrides` → not surfaced to the player

**Why:** Hand-curated word lists miss valid words (e.g. "род" in level 1), require ongoing maintenance, and don't scale to 50+ levels. A frequency-ranked dictionary gives players a consistent and fair experience while keeping common words as required targets and rare/long words as rewarding discoveries.

**Thresholds:** All four thresholds (`MIN_WORD_LENGTH` = 3, `MAX_REQUIRED_LENGTH` = 5, `FREQ_THRESHOLD` = 1000, `MAX_FREQ` = 50000) are global constants in `generate.py` and can be overridden per level by passing keyword arguments to `generate_level()`.

**Source word selection:** Source words (12+ letters) are chosen manually to ensure levels are interesting and consistent across users. A pool of 50 initial source words will be selected, spanning high, medium, and low frequency.

**Note on implementation:** Initially implemented as runtime classification via `engine/dictionary.dart`. Subsequently moved to an offline generator (`tools/level_generator/generate.py`) that writes pre-computed `required` and `bonus` arrays into the level JSON — see D11. The `engine/dictionary.dart` file and `ru_freq.txt` Flutter asset are transitional artifacts pending removal once the generator has populated all levels.

---

## D11 — All filtering in the generator; dictionary stays raw (refines D10)

**Decision:** `assets/data/ru_freq.txt` is kept raw and unmodified (Cyrillic-only entries, otherwise exactly as downloaded). All word filtering — lemmatization, POS filtering, proper noun removal, profanity blocklist, frequency thresholds, length thresholds — happens exclusively in `tools/level_generator/generate.py`.

**Why:** Keeping the dictionary raw means it never needs to be regenerated or patched when filtering rules change — only the generator needs updating. It also ensures unusual forms (interesting conjugations, place names for themed levels) can be added back via manual overrides in the level JSON without modifying the dictionary.

**Filters applied by the generator (with reasons):**
- **Proper nouns** (`Name`, `Surn`, `Patr`, `Geox`, `Orgn`, `Trad` tags) — removed by default because they are not general vocabulary; may be added back manually for themed levels (e.g. geography, literature)
- **Prepositions** (`PREP` POS) — removed because short prepositions feel like unearned answers; longer ones (перед, вокруг) may be added manually as bonus words where thematically fitting
- **Profanity** — removed via a manually maintained blocklist at `tools/level_generator/blocklist.txt`
- **Lemmatization** — only root forms included (nominative singular for nouns, infinitive for verbs, short form for adjectives) to avoid clutter from inflected duplicates; interesting conjugations may be added back manually

**Impact:** `ru_freq.txt` has a comment header stating it is raw. The Flutter runtime never touches the dictionary — it reads only pre-computed `required` and `bonus` arrays from the level JSON. `tools/level_generator/generate.py` is the authoritative source for all word classification logic.
